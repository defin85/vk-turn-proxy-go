package clientcontrol

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/buildinfo"
	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
	"github.com/defin85/vk-turn-proxy-go/internal/providerprompt"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/session"
)

const defaultHistoryLimit = 256

var (
	ErrProfileNotFound                          = errors.New("client control profile not found")
	ErrProviderConfigNotFound                   = errors.New("client control provider config not found")
	ErrSessionNotFound                          = errors.New("client control session not found")
	ErrChallengeNotFound                        = errors.New("client control challenge not found")
	ErrResolutionNotFound                       = errors.New("client control resolution not found")
	ErrPlatformTunnelModeRequired               = errors.New("platform tunnel mode is required")
	ErrPlatformTunnelModeUnknown                = errors.New("platform tunnel mode is not supported by this contract")
	ErrPlatformTunnelAppRoutingPolicyInvalid    = errors.New("platform tunnel application routing policy is invalid")
	ErrPlatformTunnelUnderlayRoutePolicyInvalid = errors.New("platform tunnel underlay route policy is invalid")
	ErrPlatformTunnelStartupAttemptRequired     = errors.New("platform tunnel startup attempt id is required")
	ErrPlatformTunnelStartupAttemptNotFound     = errors.New("platform tunnel startup attempt was not found")
)

type IncompatibleHostError struct {
	Version             string
	SupportedVersions   []string
	MissingCapabilities []Capability
}

func (e *IncompatibleHostError) Error() string {
	switch {
	case len(e.MissingCapabilities) > 0 && len(e.SupportedVersions) > 0:
		return fmt.Sprintf("incompatible client control host version=%s supported=%s missing_capabilities=%s",
			e.Version,
			strings.Join(e.SupportedVersions, ","),
			joinCapabilities(e.MissingCapabilities),
		)
	case len(e.MissingCapabilities) > 0:
		return fmt.Sprintf("client control host missing capabilities: %s", joinCapabilities(e.MissingCapabilities))
	case len(e.SupportedVersions) > 0:
		return fmt.Sprintf("incompatible client control host version=%s supported=%s",
			e.Version,
			strings.Join(e.SupportedVersions, ","),
		)
	default:
		return "incompatible client control host"
	}
}

type Option func(*hostConfig)

type challengeMode int

const (
	challengeModeControlPlane challengeMode = iota
	challengeModeCLI
)

type hostConfig struct {
	logger                       *slog.Logger
	registry                     *provider.Registry
	build                        BuildIdentity
	now                          func() time.Time
	newID                        func() string
	newSessionID                 func() string
	newRunner                    session.RunnerFactory
	resolveChallengeMetadata     func(provider.InteractiveChallenge) provider.InteractiveChallengeMetadata
	startContinuation            func(context.Context, provider.InteractiveChallenge) (browserContinuation, error)
	historyLimit                 int
	mode                         challengeMode
	cliStdin                     io.Reader
	cliStderr                    io.Writer
	promptOpts                   providerprompt.Options
	platformTunnels              []PlatformTunnelCapability
	tunnelsConfigured            bool
	transportProfileStoreEnabled bool
	transportProfileStorePath    string
	wireGuardTurnMaterializer    WireGuardTurnMaterializer
	startTunnel                  func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error)
	resumeTunnel                 func(context.Context, PlatformTunnelResumeRequest) (PlatformTunnelStartResult, error)
	stopTunnel                   func(context.Context, PlatformTunnelStopRequest) (PlatformTunnelStopResult, error)
}

type Host struct {
	mu                           sync.Mutex
	logger                       *slog.Logger
	registry                     *provider.Registry
	build                        BuildIdentity
	now                          func() time.Time
	newID                        func() string
	newSessionID                 func() string
	newRunner                    session.RunnerFactory
	resolveChallengeMetadata     func(provider.InteractiveChallenge) provider.InteractiveChallengeMetadata
	startContinuation            func(context.Context, provider.InteractiveChallenge) (browserContinuation, error)
	historyLimit                 int
	mode                         challengeMode
	cliStdin                     io.Reader
	cliStderr                    io.Writer
	promptOpts                   providerprompt.Options
	platformTunnels              []PlatformTunnelCapability
	transportProfileStoreEnabled bool
	transportProfileStorePath    string
	wireGuardTurnMaterializer    WireGuardTurnMaterializer
	startTunnel                  func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error)
	resumeTunnel                 func(context.Context, PlatformTunnelResumeRequest) (PlatformTunnelStartResult, error)
	stopTunnel                   func(context.Context, PlatformTunnelStopRequest) (PlatformTunnelStopResult, error)

	profiles                 map[string]Profile
	transportProfiles        map[string]managedTransportProfile
	transportProfileDefaults map[string]string
	providerConfigs          map[string]ProviderConfig
	resolutions              map[string]*managedResolution
	sessions                 map[string]*managedSession
	challenges               map[string]*managedChallenge
	startupRequests          map[string]PlatformTunnelStartRequest
	platformTunnelResults    map[PlatformTunnelMode]storedPlatformTunnelResult
	platformTunnelStops      map[PlatformTunnelMode]storedPlatformTunnelStop
	subscribers              map[uint64]chan Event
	nextSubID                uint64
}

type managedSession struct {
	snapshot      Session
	metrics       *observe.Metrics
	cancel        context.CancelFunc
	done          chan struct{}
	profile       ProfileSpec
	events        []Event
	challenges    []Challenge
	stopRequested bool
	platformMode  PlatformTunnelMode
}

type storedPlatformTunnelResult struct {
	request   PlatformTunnelStartRequest
	result    PlatformTunnelStartResult
	updatedAt time.Time
}

type storedPlatformTunnelStop struct {
	result    PlatformTunnelStopResult
	updatedAt time.Time
}

type managedChallenge struct {
	snapshot Challenge
	actionCh chan challengeAction
}

type browserContinuation interface {
	Complete(context.Context) (*provider.BrowserContinuation, error)
	Close() error
}

type challengeActionKind int

const (
	challengeActionContinueKind challengeActionKind = iota + 1
	challengeActionCancelKind
)

type challengeAction struct {
	kind                challengeActionKind
	browserContinuation *ChallengeContinuation
}

func New(opts ...Option) *Host {
	cfg := hostConfig{
		logger:                   slog.Default(),
		registry:                 provider.NewRegistry(genericturn.New(), vk.New()),
		build:                    toBuildIdentity(buildinfo.Current(buildinfo.Options{Role: "clientd"})),
		now:                      time.Now,
		newID:                    observe.NewSessionID,
		newSessionID:             observe.NewSessionID,
		newRunner:                nil,
		resolveChallengeMetadata: defaultInteractiveChallengeMetadata,
		startContinuation:        nil,
		historyLimit:             defaultHistoryLimit,
		mode:                     challengeModeControlPlane,
	}
	for _, opt := range opts {
		if opt != nil {
			opt(&cfg)
		}
	}
	if cfg.logger == nil {
		cfg.logger = slog.Default()
	}
	if cfg.registry == nil {
		cfg.registry = provider.NewRegistry(genericturn.New(), vk.New())
	}
	if cfg.now == nil {
		cfg.now = time.Now
	}
	if cfg.newID == nil {
		cfg.newID = observe.NewSessionID
	}
	if cfg.newSessionID == nil {
		cfg.newSessionID = observe.NewSessionID
	}
	if cfg.resolveChallengeMetadata == nil {
		cfg.resolveChallengeMetadata = defaultInteractiveChallengeMetadata
	}
	if cfg.historyLimit <= 0 {
		cfg.historyLimit = defaultHistoryLimit
	}
	if cfg.startContinuation == nil {
		cfg.startContinuation = func(ctx context.Context, challenge provider.InteractiveChallenge) (browserContinuation, error) {
			return providerprompt.StartContinuation(ctx, challenge, cfg.promptOpts)
		}
	}
	if !cfg.tunnelsConfigured {
		cfg.platformTunnels = defaultPlatformTunnelCapabilities(cfg.build)
	}
	normalizedPlatformTunnels, platformTunnelWarn := normalizePlatformTunnelCapabilities(cfg.platformTunnels, cfg.build)
	if platformTunnelWarn != nil {
		cfg.logger.Warn("invalid platform_tunnels contract configured; failing closed", "error", platformTunnelWarn)
	}
	cfg.platformTunnels = applyWireGuardTurnCarrierAvailability(
		normalizedPlatformTunnels,
		cfg.build,
		cfg.wireGuardTurnMaterializer,
		cfg.transportProfileStoreEnabled,
	)
	if cfg.startTunnel == nil {
		cfg.startTunnel = defaultPlatformTunnelStarter(cfg.platformTunnels)
	}

	host := &Host{
		logger:                       cfg.logger,
		registry:                     cfg.registry,
		build:                        cfg.build,
		now:                          cfg.now,
		newID:                        cfg.newID,
		newSessionID:                 cfg.newSessionID,
		newRunner:                    cfg.newRunner,
		resolveChallengeMetadata:     cfg.resolveChallengeMetadata,
		startContinuation:            cfg.startContinuation,
		historyLimit:                 cfg.historyLimit,
		mode:                         cfg.mode,
		cliStdin:                     cfg.cliStdin,
		cliStderr:                    cfg.cliStderr,
		promptOpts:                   cfg.promptOpts,
		platformTunnels:              cfg.platformTunnels,
		transportProfileStoreEnabled: cfg.transportProfileStoreEnabled,
		transportProfileStorePath:    strings.TrimSpace(cfg.transportProfileStorePath),
		wireGuardTurnMaterializer:    cfg.wireGuardTurnMaterializer,
		startTunnel:                  cfg.startTunnel,
		resumeTunnel:                 cfg.resumeTunnel,
		stopTunnel:                   cfg.stopTunnel,
		profiles:                     make(map[string]Profile),
		transportProfiles:            make(map[string]managedTransportProfile),
		transportProfileDefaults:     make(map[string]string),
		providerConfigs:              make(map[string]ProviderConfig),
		resolutions:                  make(map[string]*managedResolution),
		sessions:                     make(map[string]*managedSession),
		challenges:                   make(map[string]*managedChallenge),
		startupRequests:              make(map[string]PlatformTunnelStartRequest),
		platformTunnelResults:        make(map[PlatformTunnelMode]storedPlatformTunnelResult),
		platformTunnelStops:          make(map[PlatformTunnelMode]storedPlatformTunnelStop),
		subscribers:                  make(map[uint64]chan Event),
	}
	if err := host.loadTransportProfileStore(); err != nil {
		host.logger.Warn("transport profile store load failed; continuing with empty store", "error", err)
	}
	return host
}

func WithLogger(logger *slog.Logger) Option {
	return func(cfg *hostConfig) {
		cfg.logger = logger
	}
}

func WithBuildIdentity(identity BuildIdentity) Option {
	return func(cfg *hostConfig) {
		cfg.build = identity
	}
}

func WithCLIInteractivePrompts(stdin io.Reader, stderr io.Writer) Option {
	return func(cfg *hostConfig) {
		cfg.mode = challengeModeCLI
		cfg.cliStdin = stdin
		cfg.cliStderr = stderr
	}
}

func withRegistry(registry *provider.Registry) Option {
	return func(cfg *hostConfig) {
		cfg.registry = registry
	}
}

func WithRegistry(registry *provider.Registry) Option {
	return withRegistry(registry)
}

func withNow(now func() time.Time) Option {
	return func(cfg *hostConfig) {
		cfg.now = now
	}
}

func withIDSource(newID func() string) Option {
	return func(cfg *hostConfig) {
		cfg.newID = newID
	}
}

func WithSessionIDSource(newID func() string) Option {
	return func(cfg *hostConfig) {
		cfg.newSessionID = newID
	}
}

func withRunnerFactory(newRunner session.RunnerFactory) Option {
	return func(cfg *hostConfig) {
		cfg.newRunner = newRunner
	}
}

func withPromptOptions(options providerprompt.Options) Option {
	return func(cfg *hostConfig) {
		cfg.promptOpts = options
	}
}

func withContinuationStarter(start func(context.Context, provider.InteractiveChallenge) (browserContinuation, error)) Option {
	return func(cfg *hostConfig) {
		cfg.startContinuation = start
	}
}

func WithInteractiveChallengeMetadataResolver(
	resolver func(provider.InteractiveChallenge) provider.InteractiveChallengeMetadata,
) Option {
	return func(cfg *hostConfig) {
		cfg.resolveChallengeMetadata = resolver
	}
}

func (h *Host) Info() HostInfo {
	h.mu.Lock()
	capabilities := []Capability{
		CapabilityChallenges,
		CapabilityDesktopSidecar,
		CapabilityDiagnostics,
		CapabilityEventStream,
		CapabilityMobileHostBridge,
		CapabilityPlatformTunnels,
		CapabilityProfiles,
		CapabilityProviderConfigs,
		CapabilityProviderRuntimeArtifacts,
		CapabilityRuntimeExecutionPlanning,
		CapabilitySessions,
	}
	transportProfileStore := h.transportProfileStoreCapabilityLocked()
	if transportProfileStore != nil {
		capabilities = append(capabilities, CapabilityVPNTransportProfileStore)
	}
	platformTunnels := h.platformTunnelCapabilitiesWithTransportProfileStateLocked()
	h.mu.Unlock()

	return HostInfo{
		Version:               ContractVersion,
		ContractVersion:       ContractVersion,
		Build:                 h.build,
		Capabilities:          capabilities,
		PlatformTunnels:       platformTunnels,
		TransportProfileStore: cloneTransportProfileStoreCapability(transportProfileStore),
	}
}

func (h *Host) Providers() []ProviderDescriptor {
	internalDescriptors := h.registry.Descriptors()
	out := make([]ProviderDescriptor, 0, len(internalDescriptors))
	for _, descriptor := range internalDescriptors {
		converted, err := providerDescriptorFromInternal(descriptor)
		if err != nil {
			h.logger.Warn(
				"provider advertised invalid provider_settings_schema; omitting schema",
				"provider", descriptor.ID,
				"error", err,
			)
		}
		out = append(out, converted)
	}
	return out
}

func (h *Host) Negotiate(req NegotiateRequest) (HostInfo, error) {
	info := h.Info()
	if len(req.SupportedVersions) > 0 {
		compatible := false
		for _, version := range req.SupportedVersions {
			if strings.TrimSpace(version) == info.ContractVersion {
				compatible = true
				break
			}
		}
		if !compatible {
			return HostInfo{}, &IncompatibleHostError{
				Version:           info.ContractVersion,
				SupportedVersions: append([]string(nil), req.SupportedVersions...),
			}
		}
	}

	missing := missingCapabilities(info.Capabilities, req.RequiredCapabilities)
	if len(missing) > 0 {
		return HostInfo{}, &IncompatibleHostError{
			Version:             info.ContractVersion,
			MissingCapabilities: missing,
		}
	}

	return info, nil
}

func (h *Host) StartPlatformTunnel(ctx context.Context, req PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
	normalizedReq, err := normalizePlatformTunnelStartRequest(req)
	if err != nil {
		return PlatformTunnelStartResult{}, err
	}
	if !isKnownPlatformTunnelMode(req.Mode) {
		if strings.TrimSpace(string(req.Mode)) == "" {
			return PlatformTunnelStartResult{}, ErrPlatformTunnelModeRequired
		}
		return PlatformTunnelStartResult{}, ErrPlatformTunnelModeUnknown
	}
	if h.startTunnel == nil {
		return PlatformTunnelStartResult{}, fmt.Errorf("platform tunnel starter is not configured")
	}
	nextReq, profileFailure, ok := h.attachTransportProfileToStartRequest(normalizedReq)
	if ok {
		profileFailure = attachPlatformTunnelResultRequestContext(normalizedReq, profileFailure)
		if validateErr := validatePlatformTunnelStartResult(normalizedReq, profileFailure); validateErr != nil {
			return PlatformTunnelStartResult{}, fmt.Errorf("invalid platform tunnel startup result: %w", validateErr)
		}
		h.rememberPlatformTunnelResult(normalizedReq, profileFailure)
		return profileFailure, nil
	}
	normalizedReq = nextReq
	result, err := h.startTunnel(ctx, normalizedReq)
	if err != nil {
		if startResult, ok := platformTunnelStartResultFromError(err); ok {
			startResult = h.finalizePlatformTunnelFailure(ctx, normalizedReq, startResult)
			startResult = attachPlatformTunnelResultRequestContext(normalizedReq, startResult)
			if validateErr := validatePlatformTunnelStartResult(normalizedReq, startResult); validateErr != nil {
				return PlatformTunnelStartResult{}, fmt.Errorf("invalid platform tunnel startup result: %w", validateErr)
			}
			h.rememberPlatformTunnelResult(normalizedReq, startResult)
			return PlatformTunnelStartResult{}, &PlatformTunnelStartError{Result: startResult}
		}
		return PlatformTunnelStartResult{}, err
	}
	result, err = h.finalizePlatformTunnelStart(ctx, normalizedReq, result)
	if err != nil {
		return PlatformTunnelStartResult{}, err
	}
	result = attachPlatformTunnelResultRequestContext(normalizedReq, result)
	if validateErr := validatePlatformTunnelStartResult(normalizedReq, result); validateErr != nil {
		return PlatformTunnelStartResult{}, fmt.Errorf("invalid platform tunnel startup result: %w", validateErr)
	}
	h.rememberPlatformTunnelResult(normalizedReq, result)
	return result, nil
}

func (h *Host) ResumePlatformTunnel(ctx context.Context, req PlatformTunnelResumeRequest) (PlatformTunnelStartResult, error) {
	normalizedReq, err := normalizePlatformTunnelResumeRequest(req)
	if err != nil {
		return PlatformTunnelStartResult{}, err
	}
	startReq, ok := h.takePlatformTunnelStartupRequest(normalizedReq.StartupAttemptID)
	if h.resumeTunnel == nil {
		return PlatformTunnelStartResult{}, fmt.Errorf("platform tunnel resumer is not configured")
	}
	result, err := h.resumeTunnel(ctx, normalizedReq)
	if err != nil {
		if startResult, ok := platformTunnelStartResultFromError(err); ok {
			startResult = h.finalizeResumedPlatformTunnelFailure(ctx, startReq, ok, startResult)
			if ok {
				startResult = attachPlatformTunnelResultRequestContext(startReq, startResult)
			}
			if validateErr := validatePlatformTunnelStartResult(PlatformTunnelStartRequest{Mode: startResult.Mode}, startResult); validateErr != nil {
				return PlatformTunnelStartResult{}, fmt.Errorf("invalid platform tunnel startup result: %w", validateErr)
			}
			h.rememberPlatformTunnelResult(startReq, startResult)
			return PlatformTunnelStartResult{}, &PlatformTunnelStartError{Result: startResult}
		}
		return PlatformTunnelStartResult{}, err
	}
	result, err = h.finalizeResumedPlatformTunnel(ctx, normalizedReq, startReq, ok, result)
	if err != nil {
		return PlatformTunnelStartResult{}, err
	}
	if ok {
		result = attachPlatformTunnelResultRequestContext(startReq, result)
	}
	if validateErr := validatePlatformTunnelStartResult(PlatformTunnelStartRequest{Mode: result.Mode}, result); validateErr != nil {
		return PlatformTunnelStartResult{}, fmt.Errorf("invalid platform tunnel startup result: %w", validateErr)
	}
	h.rememberPlatformTunnelResult(startReq, result)
	return result, nil
}

func (h *Host) StopPlatformTunnel(ctx context.Context, req PlatformTunnelStopRequest) (PlatformTunnelStopResult, error) {
	normalizedReq, err := normalizePlatformTunnelStopRequest(req)
	if err != nil {
		return PlatformTunnelStopResult{}, err
	}
	if h.stopTunnel == nil {
		return PlatformTunnelStopResult{}, fmt.Errorf("platform tunnel stopper is not configured")
	}
	result, err := h.stopTunnel(ctx, normalizedReq)
	if err != nil {
		return PlatformTunnelStopResult{}, err
	}
	if strings.TrimSpace(string(result.Mode)) == "" {
		result.Mode = normalizedReq.Mode
	}
	if result.Mode != normalizedReq.Mode {
		return PlatformTunnelStopResult{}, fmt.Errorf(
			"invalid platform tunnel stop result: mode %s does not match requested mode %s",
			result.Mode,
			normalizedReq.Mode,
		)
	}
	if !result.Stopped {
		return PlatformTunnelStopResult{}, fmt.Errorf(
			"invalid platform tunnel stop result: mode %s did not confirm stop",
			result.Mode,
		)
	}
	h.clearPlatformTunnelStartupRequestsForMode(result.Mode)
	h.publishPlatformTunnelStop(result.Mode, "stopped")
	h.rememberPlatformTunnelStop(result)
	return result, nil
}

func (h *Host) PlatformTunnelStatuses() []PlatformTunnelStatus {
	now := h.now().UTC()
	h.mu.Lock()
	defer h.mu.Unlock()

	statuses := make(map[PlatformTunnelMode]*PlatformTunnelStatus)
	order := make([]PlatformTunnelMode, 0, len(h.platformTunnels))
	ensure := func(mode PlatformTunnelMode) *PlatformTunnelStatus {
		status, ok := statuses[mode]
		if ok {
			return status
		}
		status = &PlatformTunnelStatus{
			Mode:  mode,
			State: PlatformTunnelLifecycleStateStopped,
		}
		statuses[mode] = status
		order = append(order, mode)
		return status
	}

	for _, capability := range h.platformTunnelCapabilitiesWithTransportProfileStateLocked() {
		if capability.Mode == "" {
			continue
		}
		status := platformTunnelStatusFromCapability(capability)
		statuses[capability.Mode] = &status
		order = append(order, capability.Mode)
	}
	for attemptID, req := range h.startupRequests {
		status := ensure(req.Mode)
		applyPlatformTunnelStartRequestToStatus(status, req)
		status.State = PlatformTunnelLifecycleStatePermission
		status.Ready = false
		status.Stage = PlatformTunnelStartupStagePermissionAcquire
		status.MissingPrerequisite = PlatformTunnelPrerequisitePermission
		status.StartupAttemptID = attemptID
		if strings.TrimSpace(status.Message) == "" {
			status.Message = "platform tunnel is waiting for native VPN permission"
		}
		status.UpdatedAt = now
	}
	for mode, stored := range h.platformTunnelResults {
		status := ensure(mode)
		applyPlatformTunnelStartRequestToStatus(status, stored.request)
		applyPlatformTunnelStartResultToStatus(status, stored.result)
		status.UpdatedAt = stored.updatedAt
	}
	for _, managed := range h.sessions {
		if managed.platformMode == "" {
			continue
		}
		status := ensure(managed.platformMode)
		if status.UpdatedAt.IsZero() || !managed.snapshot.UpdatedAt.Before(status.UpdatedAt) {
			applyPlatformTunnelSessionToStatus(status, managed.snapshot)
		}
	}
	for mode, stored := range h.platformTunnelStops {
		status := ensure(mode)
		if status.UpdatedAt.IsZero() || !stored.updatedAt.Before(status.UpdatedAt) {
			applyPlatformTunnelStopToStatus(status, stored.result)
			status.UpdatedAt = stored.updatedAt
		}
	}

	for _, status := range statuses {
		if status.UpdatedAt.IsZero() {
			status.UpdatedAt = now
		}
	}
	sort.SliceStable(order, func(i, j int) bool { return order[i] < order[j] })
	out := make([]PlatformTunnelStatus, 0, len(order))
	seen := make(map[PlatformTunnelMode]bool, len(order))
	for _, mode := range order {
		if seen[mode] {
			continue
		}
		seen[mode] = true
		status := statuses[mode]
		if status == nil {
			continue
		}
		out = append(out, clonePlatformTunnelStatus(*status))
	}
	return out
}

func (h *Host) UpsertProfile(profile Profile) (Profile, error) {
	spec, err := h.normalizeProfileSpec(profile.Spec, providerSettingsModePersistedProfile)
	if err != nil {
		return Profile{}, err
	}
	profile.Spec = spec
	if strings.TrimSpace(profile.ID) == "" {
		profile.ID = h.newID()
	}

	h.mu.Lock()
	defer h.mu.Unlock()
	h.profiles[profile.ID] = profile
	return profile, nil
}

func (h *Host) DeleteProfile(profileID string) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, ok := h.profiles[profileID]; !ok {
		return ErrProfileNotFound
	}
	delete(h.profiles, profileID)
	return nil
}

func (h *Host) Profile(profileID string) (Profile, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	profile, ok := h.profiles[profileID]
	if !ok {
		return Profile{}, ErrProfileNotFound
	}
	return profile, nil
}

func (h *Host) Profiles() []Profile {
	h.mu.Lock()
	defer h.mu.Unlock()
	out := make([]Profile, 0, len(h.profiles))
	for _, profile := range h.profiles {
		out = append(out, profile)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

func (h *Host) StartSession(ctx context.Context, req StartSessionRequest) (Session, error) {
	profileID, profileName, spec, err := h.resolveStartSpec(req)
	if err != nil {
		return Session{}, err
	}
	return h.startSessionFromSpec(ctx, profileID, profileName, spec, "")
}

func (h *Host) startSessionFromSpec(ctx context.Context, profileID string, profileName string, spec ProfileSpec, sourceResolutionID string) (Session, error) {
	startedAt := h.now().UTC()
	sessionID, err := h.allocateSessionID()
	if err != nil {
		return Session{}, err
	}
	snapshotProfile := h.redactProfileSpecForOrdinaryRead(spec)
	snapshot := Session{
		ID:                 sessionID,
		ProfileID:          profileID,
		ProfileName:        profileName,
		SourceResolutionID: sourceResolutionID,
		Profile:            snapshotProfile,
		State:              SessionStateStarting,
		StartedAt:          startedAt,
		UpdatedAt:          startedAt,
	}
	if sourceResolutionID != "" {
		snapshot.Profile.Link = observeSanitizedLink(spec.Link)
	}

	runCtx, cancel := context.WithCancel(ctx)
	managed := &managedSession{
		snapshot: snapshot,
		metrics:  observe.NewMetrics(),
		cancel:   cancel,
		done:     make(chan struct{}),
		profile:  spec,
	}
	startEvent := snapshotEvent(snapshot, EventSessionStarting, "", "")

	h.mu.Lock()
	managed.events = appendWithLimit(managed.events, startEvent, h.historyLimit)
	h.sessions[sessionID] = managed
	h.mu.Unlock()

	h.publishEvent(startEvent)
	go h.runSession(runCtx, sessionID)

	return snapshot, nil
}

func (h *Host) finalizePlatformTunnelStart(
	ctx context.Context,
	req PlatformTunnelStartRequest,
	result PlatformTunnelStartResult,
) (PlatformTunnelStartResult, error) {
	if !result.Ready {
		return h.finalizePlatformTunnelFailure(ctx, req, result), nil
	}
	return h.publishReadyPlatformTunnelResult(ctx, req, result)
}

func (h *Host) finalizePlatformTunnelFailure(
	ctx context.Context,
	req PlatformTunnelStartRequest,
	result PlatformTunnelStartResult,
) PlatformTunnelStartResult {
	if strings.TrimSpace(result.StartupAttemptID) != "" {
		h.rememberPlatformTunnelStartupRequest(result.StartupAttemptID, req)
	}
	if !platformTunnelFailureNeedsCleanup(result) {
		return result
	}
	return h.attachPlatformTunnelCleanupResult(ctx, req.Mode, result)
}

func (h *Host) finalizeResumedPlatformTunnel(
	ctx context.Context,
	req PlatformTunnelResumeRequest,
	startReq PlatformTunnelStartRequest,
	haveStartReq bool,
	result PlatformTunnelStartResult,
) (PlatformTunnelStartResult, error) {
	if !result.Ready {
		return h.finalizeResumedPlatformTunnelFailure(ctx, startReq, haveStartReq, result), nil
	}
	if !haveStartReq {
		return h.platformTunnelPublicationFailure(
			ctx,
			PlatformTunnelStartRequest{Mode: result.Mode},
			result,
			fmt.Errorf("platform tunnel resume %s lost startup request context before session publication", req.StartupAttemptID),
		), nil
	}
	return h.publishReadyPlatformTunnelResult(ctx, startReq, result)
}

func (h *Host) finalizeResumedPlatformTunnelFailure(
	ctx context.Context,
	startReq PlatformTunnelStartRequest,
	haveStartReq bool,
	result PlatformTunnelStartResult,
) PlatformTunnelStartResult {
	if strings.TrimSpace(result.StartupAttemptID) != "" && haveStartReq {
		h.rememberPlatformTunnelStartupRequest(result.StartupAttemptID, startReq)
	}
	if !platformTunnelFailureNeedsCleanup(result) {
		return result
	}
	mode := result.Mode
	if strings.TrimSpace(string(mode)) == "" {
		mode = startReq.Mode
	}
	return h.attachPlatformTunnelCleanupResult(ctx, mode, result)
}

func (h *Host) publishReadyPlatformTunnelResult(
	ctx context.Context,
	req PlatformTunnelStartRequest,
	result PlatformTunnelStartResult,
) (PlatformTunnelStartResult, error) {
	session, err := h.publishPlatformTunnelSession(req)
	if err != nil {
		return h.platformTunnelPublicationFailure(ctx, req, result, err), nil
	}
	result.SessionID = session.ID
	return result, nil
}

func attachPlatformTunnelResultRequestContext(
	req PlatformTunnelStartRequest,
	result PlatformTunnelStartResult,
) PlatformTunnelStartResult {
	if strings.TrimSpace(string(result.Mode)) == "" {
		result.Mode = req.Mode
	}
	if result.ExecutionPlan == nil {
		result.ExecutionPlan = cloneRuntimeExecutionPlan(req.ExecutionPlan)
	}
	if result.TransportProfile == nil {
		result.TransportProfile = cloneTransportProfileReference(req.TransportProfile)
	}
	if strings.TrimSpace(string(result.UnderlayRoutePolicy)) == "" {
		result.UnderlayRoutePolicy = req.UnderlayRoutePolicy
	}
	return result
}

func (h *Host) platformTunnelPublicationFailure(
	ctx context.Context,
	req PlatformTunnelStartRequest,
	result PlatformTunnelStartResult,
	cause error,
) PlatformTunnelStartResult {
	message := strings.TrimSpace(cause.Error())
	if cleanupErr := h.cleanupPlatformTunnelRuntime(ctx, req.Mode); cleanupErr != nil {
		if message == "" {
			message = cleanupErr.Error()
		} else {
			message = fmt.Sprintf("%s cleanup after session publication failure also failed: %v", message, cleanupErr)
		}
	}
	if message == "" {
		message = "platform tunnel startup could not publish an ordinary session"
	}
	return PlatformTunnelStartResult{
		Mode:                result.Mode,
		ExecutionPlan:       cloneRuntimeExecutionPlan(result.ExecutionPlan),
		Ready:               false,
		Stage:               PlatformTunnelStartupStageRuntimeAttach,
		MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
		UnderlayRoutePolicy: req.UnderlayRoutePolicy,
		Message:             message,
	}
}

func (h *Host) attachPlatformTunnelCleanupResult(
	ctx context.Context,
	mode PlatformTunnelMode,
	result PlatformTunnelStartResult,
) PlatformTunnelStartResult {
	if cleanupErr := h.cleanupPlatformTunnelRuntime(ctx, mode); cleanupErr != nil {
		if strings.TrimSpace(result.Message) == "" {
			result.Message = cleanupErr.Error()
		} else {
			result.Message = fmt.Sprintf("%s cleanup after startup failure also failed: %v", result.Message, cleanupErr)
		}
	}
	return result
}

func platformTunnelFailureNeedsCleanup(result PlatformTunnelStartResult) bool {
	switch result.Stage {
	case PlatformTunnelStartupStageRouteValidate,
		PlatformTunnelStartupStageHostBringup,
		PlatformTunnelStartupStageRuntimeAttach:
		return true
	default:
		return false
	}
}

func (h *Host) cleanupPlatformTunnelRuntime(ctx context.Context, mode PlatformTunnelMode) error {
	if h.stopTunnel == nil || strings.TrimSpace(string(mode)) == "" {
		return nil
	}
	_, err := h.stopTunnel(ctx, PlatformTunnelStopRequest{Mode: mode})
	if err == nil {
		h.clearPlatformTunnelStartupRequestsForMode(mode)
		h.publishPlatformTunnelStop(mode, "stopped")
	}
	return err
}

func (h *Host) publishPlatformTunnelSession(req PlatformTunnelStartRequest) (Session, error) {
	if strings.TrimSpace(req.ResolutionID) == "" {
		return Session{}, fmt.Errorf("platform tunnel session publication requires resolution_id")
	}
	if req.RuntimeDefaults == nil {
		return Session{}, fmt.Errorf("platform tunnel session publication requires runtime_defaults")
	}
	spec, err := h.materializedProfileSpecForResolution(req.ResolutionID, *req.RuntimeDefaults)
	if err != nil {
		return Session{}, err
	}
	return h.startPlatformTunnelSession(req.Mode, spec, req.ResolutionID)
}

func (h *Host) materializedProfileSpecForResolution(
	resolutionID string,
	defaults RuntimeDefaults,
) (ProfileSpec, error) {
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return ProfileSpec{}, ErrResolutionNotFound
	}
	event := h.expireResolutionLocked(managed)
	snapshot := managed.snapshot
	secret := managed.secret
	h.mu.Unlock()

	if event != nil {
		h.publishEvent(*event)
	}
	if snapshot.State == ResolutionStateExpired {
		return ProfileSpec{}, errResolutionExpired
	}
	if snapshot.State != ResolutionStateResolved {
		return ProfileSpec{}, errResolutionNotTransportReady
	}
	if !resolutionSupportsAction(snapshot, ArtifactActionStartOnThisDevice) {
		return ProfileSpec{}, &ResolutionActionError{
			Action: ArtifactActionStartOnThisDevice,
			Err:    errResolutionNotTransportReady,
		}
	}
	return buildMaterializedProfileSpec(secret.Credentials, defaults)
}

func (h *Host) startPlatformTunnelSession(
	mode PlatformTunnelMode,
	spec ProfileSpec,
	sourceResolutionID string,
) (Session, error) {
	startedAt := h.now().UTC()
	sessionID, err := h.allocateSessionID()
	if err != nil {
		return Session{}, err
	}
	startingSnapshot := Session{
		ID:                 sessionID,
		SourceResolutionID: sourceResolutionID,
		Profile:            h.redactProfileSpecForOrdinaryRead(spec),
		State:              SessionStateStarting,
		StartedAt:          startedAt,
		UpdatedAt:          startedAt,
	}
	if sourceResolutionID != "" {
		startingSnapshot.Profile.Link = observeSanitizedLink(spec.Link)
	}
	readySnapshot := startingSnapshot
	readySnapshot.State = SessionStateReady
	managed := &managedSession{
		snapshot:     readySnapshot,
		metrics:      observe.NewMetrics(),
		done:         make(chan struct{}),
		profile:      spec,
		platformMode: mode,
	}
	startEvent := snapshotEvent(startingSnapshot, EventSessionStarting, "", "")
	readyEvent := snapshotEvent(readySnapshot, EventSessionReady, string(PlatformTunnelStartupStageRuntimeAttach), "")
	replacementEvents := make([]Event, 0)

	h.mu.Lock()
	replacementEvents = h.markPlatformTunnelSessionsStoppedLocked(mode, startedAt, "replaced")
	managed.events = appendWithLimit(managed.events, startEvent, h.historyLimit)
	managed.events = appendWithLimit(managed.events, readyEvent, h.historyLimit)
	h.sessions[sessionID] = managed
	h.mu.Unlock()

	for _, event := range replacementEvents {
		h.publishEvent(event)
	}
	h.publishEvent(startEvent)
	h.publishEvent(readyEvent)

	return readySnapshot, nil
}

func (h *Host) publishPlatformTunnelStop(mode PlatformTunnelMode, message string) {
	h.mu.Lock()
	events := h.markPlatformTunnelSessionsStoppedLocked(mode, h.now().UTC(), message)
	h.mu.Unlock()
	for _, event := range events {
		h.publishEvent(event)
	}
}

func (h *Host) markPlatformTunnelSessionsStoppedLocked(
	mode PlatformTunnelMode,
	now time.Time,
	message string,
) []Event {
	events := make([]Event, 0)
	for _, managed := range h.sessions {
		if managed.platformMode != mode {
			continue
		}
		switch managed.snapshot.State {
		case SessionStateStopped, SessionStateFailed:
			continue
		}
		managed.snapshot.State = SessionStateStopped
		managed.snapshot.ActiveChallengeID = ""
		managed.snapshot.UpdatedAt = now
		stoppedAt := now
		managed.snapshot.StoppedAt = &stoppedAt
		event := snapshotEvent(managed.snapshot, EventSessionStopped, "", message)
		managed.events = appendWithLimit(managed.events, event, h.historyLimit)
		select {
		case <-managed.done:
		default:
			close(managed.done)
		}
		events = append(events, event)
	}
	return events
}

func (h *Host) rememberPlatformTunnelStartupRequest(attemptID string, req PlatformTunnelStartRequest) {
	attemptID = strings.TrimSpace(attemptID)
	if attemptID == "" {
		return
	}
	h.mu.Lock()
	h.startupRequests[attemptID] = req
	h.mu.Unlock()
}

func (h *Host) takePlatformTunnelStartupRequest(attemptID string) (PlatformTunnelStartRequest, bool) {
	attemptID = strings.TrimSpace(attemptID)
	if attemptID == "" {
		return PlatformTunnelStartRequest{}, false
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	req, ok := h.startupRequests[attemptID]
	if ok {
		delete(h.startupRequests, attemptID)
	}
	return req, ok
}

func (h *Host) clearPlatformTunnelStartupRequestsForMode(mode PlatformTunnelMode) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for attemptID, req := range h.startupRequests {
		if req.Mode == mode {
			delete(h.startupRequests, attemptID)
		}
	}
}

func (h *Host) rememberPlatformTunnelResult(req PlatformTunnelStartRequest, result PlatformTunnelStartResult) {
	if result.Mode == "" {
		return
	}
	h.mu.Lock()
	h.platformTunnelResults[result.Mode] = storedPlatformTunnelResult{
		request:   clonePlatformTunnelStartRequest(req),
		result:    clonePlatformTunnelStartResult(result),
		updatedAt: h.now().UTC(),
	}
	h.mu.Unlock()
}

func (h *Host) rememberPlatformTunnelStop(result PlatformTunnelStopResult) {
	if result.Mode == "" {
		return
	}
	h.mu.Lock()
	h.platformTunnelStops[result.Mode] = storedPlatformTunnelStop{
		result:    clonePlatformTunnelStopResult(result),
		updatedAt: h.now().UTC(),
	}
	h.mu.Unlock()
}

func platformTunnelStatusFromCapability(capability PlatformTunnelCapability) PlatformTunnelStatus {
	status := PlatformTunnelStatus{
		Mode:  capability.Mode,
		State: PlatformTunnelLifecycleStateStopped,
	}
	descriptor := preferredPlatformTunnelStatusDescriptor(capability)
	if descriptor != nil {
		status.ExecutionPlan = cloneRuntimeExecutionPlan(&descriptor.Plan)
		if descriptor.TransportProfile != nil {
			status.TransportProfile = cloneTransportProfileReference(firstTransportProfileReference(
				descriptor.TransportProfile.SelectedProfile,
				descriptor.TransportProfile.DefaultProfile,
			))
			if descriptor.TransportProfile.State != TransportProfileCompatibilityStateCompatible {
				status.State = PlatformTunnelLifecycleStateSetupNeeded
				status.Stage = PlatformTunnelStartupStageProfileValidate
				status.MissingPrerequisite = PlatformTunnelPrerequisiteTransportProfile
				status.Message = descriptor.TransportProfile.Message
				return status
			}
		}
		if descriptor.SupportState != RuntimeExecutionPlanSupportStateSupported {
			status.State = PlatformTunnelLifecycleStateFailed
			status.Stage = PlatformTunnelStartupStageCapabilityCheck
			status.MissingPrerequisite = PlatformTunnelPrerequisiteHostImplementation
			status.Message = runtimeExecutionPlanUnavailableMessage(*descriptor)
			return status
		}
	}
	if !capability.Available {
		status.State = PlatformTunnelLifecycleStateFailed
		status.Stage = PlatformTunnelStartupStageCapabilityCheck
		status.MissingPrerequisite = capability.MissingPrerequisite
		if status.MissingPrerequisite == "" {
			status.MissingPrerequisite = PlatformTunnelPrerequisiteHostImplementation
		}
		status.Message = capability.Message
	}
	return status
}

func preferredPlatformTunnelStatusDescriptor(
	capability PlatformTunnelCapability,
) *RuntimeExecutionPlanDescriptor {
	if descriptor, err := selectRuntimeExecutionPlanDescriptor(capability.ExecutionPlans, nil); err == nil {
		return descriptor
	}
	if descriptor, err := selectPlatformTunnelExecutionPlanDescriptor(capability.ExecutionPlans, nil); err == nil {
		return descriptor
	}
	if len(capability.ExecutionPlans) == 0 {
		return nil
	}
	descriptor := capability.ExecutionPlans[0]
	return &descriptor
}

func firstTransportProfileReference(refs ...*TransportProfileReference) *TransportProfileReference {
	for _, ref := range refs {
		if ref != nil && strings.TrimSpace(ref.ProfileID) != "" {
			return ref
		}
	}
	return nil
}

func applyPlatformTunnelStartRequestToStatus(status *PlatformTunnelStatus, req PlatformTunnelStartRequest) {
	if req.Mode != "" {
		status.Mode = req.Mode
	}
	if strings.TrimSpace(req.ResolutionID) != "" {
		status.SourceResolutionID = req.ResolutionID
	}
	if req.ExecutionPlan != nil {
		status.ExecutionPlan = cloneRuntimeExecutionPlan(req.ExecutionPlan)
	}
	if req.TransportProfile != nil {
		status.TransportProfile = cloneTransportProfileReference(req.TransportProfile)
	}
	if req.ApplicationRoutingPolicy != "" {
		status.ApplicationRoutingPolicy = req.ApplicationRoutingPolicy
	}
	if req.UnderlayRoutePolicy != "" {
		status.UnderlayRoutePolicy = req.UnderlayRoutePolicy
	}
	status.AllowedPackages = cloneStringSlice(req.AllowedPackages)
	status.DisallowedPackages = cloneStringSlice(req.DisallowedPackages)
}

func applyPlatformTunnelStartResultToStatus(status *PlatformTunnelStatus, result PlatformTunnelStartResult) {
	if result.Mode != "" {
		status.Mode = result.Mode
	}
	if result.ExecutionPlan != nil {
		status.ExecutionPlan = cloneRuntimeExecutionPlan(result.ExecutionPlan)
	}
	if result.TransportProfile != nil {
		status.TransportProfile = cloneTransportProfileReference(result.TransportProfile)
	}
	if result.UnderlayRoutePolicy != "" {
		status.UnderlayRoutePolicy = result.UnderlayRoutePolicy
	}
	status.Message = result.Message
	status.Stage = result.Stage
	status.MissingPrerequisite = result.MissingPrerequisite
	status.StartupAttemptID = result.StartupAttemptID
	status.SessionID = result.SessionID
	status.Ready = result.Ready
	switch {
	case result.Ready:
		status.State = PlatformTunnelLifecycleStateReady
		status.MissingPrerequisite = ""
		status.StartupAttemptID = ""
	case result.Stage == PlatformTunnelStartupStagePermissionAcquire &&
		result.MissingPrerequisite == PlatformTunnelPrerequisitePermission &&
		strings.TrimSpace(result.StartupAttemptID) != "":
		status.State = PlatformTunnelLifecycleStatePermission
	case result.Stage == PlatformTunnelStartupStageProfileValidate ||
		result.MissingPrerequisite == PlatformTunnelPrerequisiteTransportProfile:
		status.State = PlatformTunnelLifecycleStateSetupNeeded
	default:
		status.State = PlatformTunnelLifecycleStateFailed
	}
}

func applyPlatformTunnelSessionToStatus(status *PlatformTunnelStatus, session Session) {
	status.SessionID = session.ID
	status.SourceResolutionID = session.SourceResolutionID
	status.UpdatedAt = session.UpdatedAt
	status.StartupAttemptID = ""
	switch session.State {
	case SessionStateReady:
		status.State = PlatformTunnelLifecycleStateReady
		status.Ready = true
		status.Stage = PlatformTunnelStartupStageRuntimeAttach
		status.MissingPrerequisite = ""
		status.Message = ""
	case SessionStateStarting, SessionStateRetrying:
		status.State = PlatformTunnelLifecycleStateStarting
		status.Ready = false
	case SessionStateStopping:
		status.State = PlatformTunnelLifecycleStateStopping
		status.Ready = false
	case SessionStateStopped:
		status.State = PlatformTunnelLifecycleStateStopped
		status.Ready = false
		status.Stage = ""
		status.MissingPrerequisite = ""
	case SessionStateFailed:
		status.State = PlatformTunnelLifecycleStateFailed
		status.Ready = false
		if session.Failure != nil {
			status.Message = session.Failure.Message
			status.Stage = platformTunnelStartupStageFromString(session.Failure.Stage)
		}
		if status.MissingPrerequisite == "" {
			status.MissingPrerequisite = PlatformTunnelPrerequisiteHostImplementation
		}
	}
}

func applyPlatformTunnelStopToStatus(status *PlatformTunnelStatus, result PlatformTunnelStopResult) {
	if result.Mode != "" {
		status.Mode = result.Mode
	}
	status.State = PlatformTunnelLifecycleStateStopped
	status.Ready = false
	status.Stage = ""
	status.MissingPrerequisite = ""
	status.StartupAttemptID = ""
	if strings.TrimSpace(result.Message) != "" {
		status.Message = result.Message
	}
}

func clonePlatformTunnelStatus(status PlatformTunnelStatus) PlatformTunnelStatus {
	status.ExecutionPlan = cloneRuntimeExecutionPlan(status.ExecutionPlan)
	status.TransportProfile = cloneTransportProfileReference(status.TransportProfile)
	status.AllowedPackages = cloneStringSlice(status.AllowedPackages)
	status.DisallowedPackages = cloneStringSlice(status.DisallowedPackages)
	return status
}

func clonePlatformTunnelStartRequest(req PlatformTunnelStartRequest) PlatformTunnelStartRequest {
	req.ExecutionPlan = cloneRuntimeExecutionPlan(req.ExecutionPlan)
	req.TransportProfile = cloneTransportProfileReference(req.TransportProfile)
	if req.RuntimeDefaults != nil {
		defaults := *req.RuntimeDefaults
		req.RuntimeDefaults = &defaults
	}
	req.AllowedPackages = cloneStringSlice(req.AllowedPackages)
	req.DisallowedPackages = cloneStringSlice(req.DisallowedPackages)
	return req
}

func clonePlatformTunnelStartResult(result PlatformTunnelStartResult) PlatformTunnelStartResult {
	result.ExecutionPlan = cloneRuntimeExecutionPlan(result.ExecutionPlan)
	result.TransportProfile = cloneTransportProfileReference(result.TransportProfile)
	result.UnderlayRouteExclusions = cloneStringSlice(result.UnderlayRouteExclusions)
	return result
}

func clonePlatformTunnelStopResult(result PlatformTunnelStopResult) PlatformTunnelStopResult {
	return result
}

func cloneStringSlice(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	return append([]string(nil), values...)
}

func platformTunnelStartupStageFromString(raw string) PlatformTunnelStartupStage {
	stage := PlatformTunnelStartupStage(strings.TrimSpace(raw))
	switch stage {
	case PlatformTunnelStartupStageCapabilityCheck,
		PlatformTunnelStartupStagePermissionAcquire,
		PlatformTunnelStartupStageEntitlementAcquire,
		PlatformTunnelStartupStageDriverCheck,
		PlatformTunnelStartupStageProfileValidate,
		PlatformTunnelStartupStageRouteValidate,
		PlatformTunnelStartupStageHostBringup,
		PlatformTunnelStartupStageRuntimeAttach:
		return stage
	default:
		return ""
	}
}

func (h *Host) StopSession(sessionID string) (Session, error) {
	h.mu.Lock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		h.mu.Unlock()
		return Session{}, ErrSessionNotFound
	}
	if managed.platformMode != "" {
		mode := managed.platformMode
		h.mu.Unlock()
		if _, err := h.StopPlatformTunnel(context.Background(), PlatformTunnelStopRequest{Mode: mode}); err != nil {
			return Session{}, err
		}
		return h.Session(sessionID)
	}
	if managed.snapshot.State == SessionStateStopped || managed.snapshot.State == SessionStateFailed {
		snapshot := managed.snapshot
		h.mu.Unlock()
		return snapshot, nil
	}
	now := h.now().UTC()
	managed.stopRequested = true
	managed.snapshot.State = SessionStateStopping
	managed.snapshot.UpdatedAt = now
	snapshot := managed.snapshot
	stopEvent := snapshotEvent(snapshot, EventSessionStopped, "", "stopping")
	managed.events = appendWithLimit(managed.events, stopEvent, h.historyLimit)
	cancel := managed.cancel
	h.mu.Unlock()

	h.publishEvent(stopEvent)
	cancel()
	return snapshot, nil
}

func (h *Host) Session(sessionID string) (Session, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		return Session{}, ErrSessionNotFound
	}
	return managed.snapshot, nil
}

func (h *Host) Sessions() []Session {
	h.mu.Lock()
	defer h.mu.Unlock()
	out := make([]Session, 0, len(h.sessions))
	for _, managed := range h.sessions {
		out = append(out, managed.snapshot)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].StartedAt.Before(out[j].StartedAt) })
	return out
}

func (h *Host) WaitSession(ctx context.Context, sessionID string) (Session, error) {
	h.mu.Lock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		h.mu.Unlock()
		return Session{}, ErrSessionNotFound
	}
	done := managed.done
	h.mu.Unlock()

	select {
	case <-ctx.Done():
		return Session{}, ctx.Err()
	case <-done:
		return h.Session(sessionID)
	}
}

func (h *Host) Challenge(challengeID string) (Challenge, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	managed, ok := h.challenges[challengeID]
	if !ok {
		return Challenge{}, ErrChallengeNotFound
	}
	return managed.snapshot, nil
}

func (h *Host) ContinueChallenge(challengeID string) (Challenge, error) {
	return h.ContinueChallengeWithBrowserContinuation(challengeID, nil)
}

func (h *Host) ContinueChallengeWithBrowserContinuation(
	challengeID string,
	continuation *ChallengeContinuation,
) (Challenge, error) {
	return h.signalChallenge(challengeID, challengeAction{
		kind:                challengeActionContinueKind,
		browserContinuation: continuation,
	}, ChallengeStatusContinuing)
}

func (h *Host) CancelChallenge(challengeID string) (Challenge, error) {
	return h.signalChallenge(challengeID, challengeAction{
		kind: challengeActionCancelKind,
	}, ChallengeStatusCancelled)
}

func (h *Host) MetricsHandler(sessionID string) (http.Handler, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		return nil, ErrSessionNotFound
	}
	mux := http.NewServeMux()
	mux.Handle("/metrics", managed.metrics.Handler())
	return mux, nil
}

func (h *Host) ExportDiagnostics(sessionID string) (Diagnostics, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		return Diagnostics{}, ErrSessionNotFound
	}
	events := append([]Event(nil), managed.events...)
	challenges := append([]Challenge(nil), managed.challenges...)
	return Diagnostics{
		Session:         managed.snapshot,
		Events:          events,
		Challenges:      challenges,
		Metrics:         managed.metrics.Prometheus(),
		HostBuild:       h.build,
		ContractVersion: ContractVersion,
	}, nil
}

func toBuildIdentity(identity buildinfo.Identity) BuildIdentity {
	return BuildIdentity{
		Product:     identity.Product,
		Version:     identity.Version,
		BuildNumber: identity.BuildNumber,
		Revision:    identity.Revision,
		Dirty:       identity.Dirty,
		BuiltAt:     identity.BuiltAt,
		Role:        identity.Role,
		Target:      identity.Target,
	}
}

func (h *Host) Subscribe(buffer int) (<-chan Event, func()) {
	if buffer <= 0 {
		buffer = 32
	}
	ch := make(chan Event, buffer)

	h.mu.Lock()
	id := h.nextSubID
	h.nextSubID++
	h.subscribers[id] = ch
	h.mu.Unlock()

	cancel := func() {
		h.mu.Lock()
		existing, ok := h.subscribers[id]
		if ok {
			delete(h.subscribers, id)
		}
		h.mu.Unlock()
		if ok {
			close(existing)
		}
	}

	return ch, cancel
}

func (h *Host) resolveStartSpec(req StartSessionRequest) (string, string, ProfileSpec, error) {
	if req.Spec != nil {
		spec, err := h.normalizeProfileSpec(*req.Spec, providerSettingsModeImmediate)
		return "", "", spec, err
	}
	if strings.TrimSpace(req.ProfileID) == "" {
		return "", "", ProfileSpec{}, errors.New("profile_id or spec is required")
	}
	h.mu.Lock()
	profile, ok := h.profiles[req.ProfileID]
	h.mu.Unlock()
	if !ok {
		return "", "", ProfileSpec{}, ErrProfileNotFound
	}
	spec, err := h.normalizeProfileSpec(profile.Spec, providerSettingsModeImmediate)
	if err != nil {
		return "", "", ProfileSpec{}, err
	}
	return profile.ID, profile.Name, spec, nil
}

func (h *Host) allocateSessionID() (string, error) {
	for attempts := 0; attempts < 8; attempts++ {
		candidate := strings.TrimSpace(h.newSessionID())
		if candidate == "" {
			continue
		}
		h.mu.Lock()
		_, exists := h.sessions[candidate]
		h.mu.Unlock()
		if !exists {
			return candidate, nil
		}
	}
	return "", errors.New("client control session id allocation failed")
}

func (h *Host) runSession(ctx context.Context, sessionID string) {
	h.mu.Lock()
	managed := h.sessions[sessionID]
	spec := managed.profile
	metrics := managed.metrics
	h.mu.Unlock()

	logger := slog.New(newRuntimeHandler(h.logger, func(ctx context.Context, record runtimeRecord) {
		h.handleRuntimeRecord(sessionID, record)
	}))

	runCtx := ctx
	if spec.InteractiveProvider {
		switch h.mode {
		case challengeModeCLI:
			handler := providerprompt.NewHandler(h.cliStdin, h.cliStderr, h.promptOpts)
			runCtx = provider.WithInteractionHandler(runCtx, handler)
			runCtx = provider.WithBrowserContinuationHandler(runCtx, handler)
		default:
			broker := &challengeBroker{host: h, sessionID: sessionID}
			runCtx = provider.WithInteractionHandler(runCtx, broker)
			runCtx = provider.WithBrowserContinuationHandler(runCtx, broker)
		}
	}

	err := session.Run(runCtx, translateProfileSpec(spec), session.Dependencies{
		Registry:  h.registry,
		Logger:    logger,
		Metrics:   metrics,
		SessionID: session.ID(sessionID),
		NewRunner: h.newRunner,
	})

	h.finishSession(sessionID, err)
}

func (h *Host) finishSession(sessionID string, err error) {
	h.mu.Lock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		h.mu.Unlock()
		return
	}
	now := h.now().UTC()
	if managed.snapshot.State != SessionStateFailed {
		managed.snapshot.UpdatedAt = now
		managed.snapshot.StoppedAt = &now
		if managed.stopRequested || errors.Is(err, context.Canceled) || err == nil {
			managed.snapshot.State = SessionStateStopped
		} else {
			stage, _ := runstage.FromError(err)
			managed.snapshot.State = SessionStateFailed
			managed.snapshot.Failure = &FailureInfo{
				Stage:          string(stage),
				Message:        err.Error(),
				NotImplemented: errors.Is(err, provider.ErrNotImplemented),
			}
		}
	}
	snapshot := managed.snapshot
	done := managed.done
	alreadyClosed := false
	select {
	case <-done:
		alreadyClosed = true
	default:
	}
	h.mu.Unlock()

	if managed.snapshot.State == SessionStateStopped {
		stopEvent := snapshotEvent(snapshot, EventSessionStopped, "", "stopped")
		h.mu.Lock()
		if managed, ok := h.sessions[sessionID]; ok {
			managed.events = appendWithLimit(managed.events, stopEvent, h.historyLimit)
		}
		h.mu.Unlock()
		h.publishEvent(stopEvent)
	}

	if !alreadyClosed {
		close(done)
	}
}

func (h *Host) handleRuntimeRecord(sessionID string, record runtimeRecord) {
	now := h.now().UTC()
	h.mu.Lock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		h.mu.Unlock()
		return
	}

	eventName := stringValue(record.attrs["event"])
	stage := stringValue(record.attrs["stage"])
	result := stringValue(record.attrs["result"])

	var event Event
	switch eventName {
	case "runtime_ready":
		managed.snapshot.State = SessionStateReady
		managed.snapshot.UpdatedAt = now
		managed.snapshot.ActiveChallengeID = ""
		event = Event{
			ID:           h.newID(),
			Timestamp:    now,
			SessionID:    sessionID,
			Type:         EventSessionReady,
			State:        SessionStateReady,
			Stage:        stage,
			Connections:  intValue(record.attrs["connections"]),
			ReadyWorkers: intValue(record.attrs["connections"]),
		}
	case "worker_restart_scheduled":
		managed.snapshot.State = SessionStateRetrying
		managed.snapshot.UpdatedAt = now
		event = Event{
			ID:        h.newID(),
			Timestamp: now,
			SessionID: sessionID,
			Type:      EventSessionRetrying,
			State:     SessionStateRetrying,
			Stage:     stage,
			Message:   result,
			Restart:   intValue(record.attrs["restart"]),
			Backoff:   fmt.Sprint(record.attrs["backoff"]),
		}
	case "runtime_failure":
		managed.snapshot.State = SessionStateFailed
		managed.snapshot.UpdatedAt = now
		managed.snapshot.StoppedAt = &now
		managed.snapshot.Failure = &FailureInfo{
			Stage:   stage,
			Message: stringValue(record.attrs["error"]),
		}
		event = Event{
			ID:        h.newID(),
			Timestamp: now,
			SessionID: sessionID,
			Type:      EventSessionFailed,
			State:     SessionStateFailed,
			Stage:     stage,
			Message:   stringValue(record.attrs["error"]),
		}
	case "runtime_startup":
		managed.snapshot.State = SessionStateStarting
		managed.snapshot.UpdatedAt = now
		event = Event{
			ID:          h.newID(),
			Timestamp:   now,
			SessionID:   sessionID,
			Type:        EventSessionStarting,
			State:       SessionStateStarting,
			Stage:       stage,
			Connections: intValue(record.attrs["connections"]),
		}
	default:
		h.mu.Unlock()
		return
	}

	managed.events = appendWithLimit(managed.events, event, h.historyLimit)
	snapshot := managed.snapshot
	h.mu.Unlock()

	if event.Type == EventSessionReady && snapshot.ActiveChallengeID == "" {
		h.clearPendingChallenges(sessionID)
	}
	h.publishEvent(event)
}

func (h *Host) recordChallenge(sessionID string, challenge Challenge) {
	h.mu.Lock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		h.mu.Unlock()
		return
	}
	managed.snapshot.State = SessionStateChallengeRequired
	managed.snapshot.ActiveChallengeID = challenge.ID
	managed.snapshot.UpdatedAt = challenge.UpdatedAt
	managed.challenges = appendWithLimit(managed.challenges, challenge, h.historyLimit)
	managedChallenge := &managedChallenge{
		snapshot: challenge,
		actionCh: make(chan challengeAction, 1),
	}
	h.challenges[challenge.ID] = managedChallenge
	managed.events = appendWithLimit(managed.events, Event{
		ID:        h.newID(),
		Timestamp: challenge.CreatedAt,
		SessionID: sessionID,
		Type:      EventChallengeRequired,
		State:     SessionStateChallengeRequired,
		Challenge: cloneChallenge(&challenge),
	}, h.historyLimit)
	h.mu.Unlock()

	h.publishEvent(Event{
		ID:        h.newID(),
		Timestamp: challenge.CreatedAt,
		SessionID: sessionID,
		Type:      EventChallengeRequired,
		State:     SessionStateChallengeRequired,
		Challenge: cloneChallenge(&challenge),
	})
}

func (h *Host) completeChallenge(challengeID string, status ChallengeStatus, message string) {
	h.mu.Lock()
	managedChallenge, ok := h.challenges[challengeID]
	if !ok {
		h.mu.Unlock()
		return
	}
	managedChallenge.snapshot.Status = status
	managedChallenge.snapshot.UpdatedAt = h.now().UTC()
	challenge := managedChallenge.snapshot
	sessionID := challenge.SessionID
	resolutionID := challenge.ResolutionID
	sessionState := SessionState("")
	resolutionState := ResolutionState("")
	if managedSession, ok := h.sessions[sessionID]; ok {
		managedSession.snapshot.ActiveChallengeID = ""
		if status == ChallengeStatusCompleted {
			managedSession.snapshot.State = SessionStateStarting
		}
		managedSession.snapshot.UpdatedAt = challenge.UpdatedAt
		managedSession.challenges = replaceChallenge(managedSession.challenges, challenge)
		sessionState = managedSession.snapshot.State
		managedSession.events = appendWithLimit(managedSession.events, Event{
			ID:              h.newID(),
			Timestamp:       challenge.UpdatedAt,
			SessionID:       sessionID,
			ResolutionID:    resolutionID,
			Type:            EventChallengeUpdated,
			State:           managedSession.snapshot.State,
			ResolutionState: resolutionState,
			Message:         message,
			Challenge:       cloneChallenge(&challenge),
		}, h.historyLimit)
	}
	if managedResolution, ok := h.resolutions[resolutionID]; ok {
		managedResolution.snapshot.ActiveChallengeID = ""
		if status == ChallengeStatusCompleted {
			managedResolution.snapshot.State = ResolutionStateStarting
		}
		managedResolution.snapshot.UpdatedAt = challenge.UpdatedAt
		managedResolution.challenges = replaceChallenge(managedResolution.challenges, challenge)
		resolutionState = managedResolution.snapshot.State
	}
	h.mu.Unlock()

	h.publishEvent(Event{
		ID:              h.newID(),
		Timestamp:       challenge.UpdatedAt,
		SessionID:       sessionID,
		ResolutionID:    resolutionID,
		Type:            EventChallengeUpdated,
		State:           sessionState,
		ResolutionState: resolutionState,
		Message:         message,
		Challenge:       cloneChallenge(&challenge),
	})
}

func (h *Host) waitChallengeAction(ctx context.Context, challengeID string) (challengeAction, error) {
	h.mu.Lock()
	managed, ok := h.challenges[challengeID]
	h.mu.Unlock()
	if !ok {
		return challengeAction{}, ErrChallengeNotFound
	}

	select {
	case <-ctx.Done():
		return challengeAction{}, ctx.Err()
	case action := <-managed.actionCh:
		return action, nil
	}
}

func (h *Host) signalChallenge(challengeID string, action challengeAction, status ChallengeStatus) (Challenge, error) {
	h.mu.Lock()
	managed, ok := h.challenges[challengeID]
	if !ok {
		h.mu.Unlock()
		return Challenge{}, ErrChallengeNotFound
	}
	if err := validateChallengeContinuationRequest(managed.snapshot, action); err != nil {
		h.mu.Unlock()
		return Challenge{}, err
	}
	managed.snapshot.Status = status
	managed.snapshot.UpdatedAt = h.now().UTC()
	challenge := managed.snapshot
	sessionID := challenge.SessionID
	resolutionID := challenge.ResolutionID
	sessionState := SessionState("")
	resolutionState := ResolutionState("")
	if managedSession, ok := h.sessions[sessionID]; ok {
		managedSession.challenges = replaceChallenge(managedSession.challenges, challenge)
		sessionState = managedSession.snapshot.State
	}
	if managedResolution, ok := h.resolutions[resolutionID]; ok {
		managedResolution.challenges = replaceChallenge(managedResolution.challenges, challenge)
		resolutionState = managedResolution.snapshot.State
	}
	actionCh := managed.actionCh
	h.mu.Unlock()

	select {
	case actionCh <- action:
	default:
	}

	event := Event{
		ID:              h.newID(),
		Timestamp:       challenge.UpdatedAt,
		SessionID:       sessionID,
		ResolutionID:    resolutionID,
		Type:            EventChallengeUpdated,
		State:           sessionState,
		ResolutionState: resolutionState,
		Challenge:       cloneChallenge(&challenge),
	}
	h.mu.Lock()
	if managedSession, ok := h.sessions[sessionID]; ok {
		managedSession.events = appendWithLimit(managedSession.events, event, h.historyLimit)
	}
	if managedResolution, ok := h.resolutions[resolutionID]; ok {
		managedResolution.events = appendWithLimit(managedResolution.events, event, h.historyLimit)
	}
	h.mu.Unlock()
	h.publishEvent(event)
	return challenge, nil
}

func (h *Host) publishEvent(event Event) {
	if event.ID == "" {
		event.ID = h.newID()
	}

	h.mu.Lock()
	subscribers := make([]chan Event, 0, len(h.subscribers))
	for _, ch := range h.subscribers {
		subscribers = append(subscribers, ch)
	}
	h.mu.Unlock()

	for _, ch := range subscribers {
		select {
		case ch <- event:
		default:
		}
	}
}

func (h *Host) challengeMetadata(
	challenge provider.InteractiveChallenge,
) provider.InteractiveChallengeMetadata {
	if h.resolveChallengeMetadata == nil {
		return defaultInteractiveChallengeMetadata(challenge)
	}
	return h.resolveChallengeMetadata(challenge)
}

func (h *Host) buildChallengeRecord(
	id string,
	sessionID string,
	resolutionID string,
	challenge provider.InteractiveChallenge,
) Challenge {
	metadata := h.challengeMetadata(challenge)
	completionMode, browserReturn, ownedBrowser :=
		challengeContractMetadataFromProviderMetadata(challenge, metadata)
	now := h.now().UTC()
	return Challenge{
		ID:             id,
		SessionID:      sessionID,
		ResolutionID:   resolutionID,
		Provider:       challenge.ProviderName(),
		Stage:          challenge.StageName(),
		Kind:           challenge.Kind(),
		Prompt:         providerprompt.ContinuationPrompt(challenge),
		OpenURL:        providerprompt.ContinuationOpenURL(challenge),
		Status:         ChallengeStatusPending,
		CompletionMode: completionMode,
		BrowserReturn:  browserReturn,
		OwnedBrowser:   ownedBrowser,
		CreatedAt:      now,
		UpdatedAt:      now,
	}
}

func validateChallengeContinuationRequest(
	challenge Challenge,
	action challengeAction,
) error {
	if action.kind != challengeActionContinueKind {
		return nil
	}
	switch challenge.CompletionMode {
	case ChallengeCompletionModeOwnedBrowserObserved:
		if action.browserContinuation == nil {
			return errors.New("owned browser continuation payload is required for this challenge")
		}
	default:
		if action.browserContinuation != nil {
			return errors.New("browser continuation payload is not supported for this challenge")
		}
	}
	return nil
}

func (h *Host) clearPendingChallenges(sessionID string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for id, challenge := range h.challenges {
		if challenge.snapshot.SessionID != sessionID {
			continue
		}
		if challenge.snapshot.Status == ChallengeStatusPending || challenge.snapshot.Status == ChallengeStatusContinuing {
			challenge.snapshot.Status = ChallengeStatusCompleted
			challenge.snapshot.UpdatedAt = h.now().UTC()
			h.challenges[id] = challenge
		}
	}
}

type challengeBroker struct {
	host      *Host
	sessionID string
}

func (b *challengeBroker) Handle(ctx context.Context, challenge provider.InteractiveChallenge) error {
	if challenge == nil {
		return errors.New("interactive provider challenge is required")
	}

	record := b.host.buildChallengeRecord(
		b.host.newID(),
		b.sessionID,
		"",
		challenge,
	)
	b.host.recordChallenge(b.sessionID, record)

	action, err := b.host.waitChallengeAction(ctx, record.ID)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return fmt.Errorf("interactive provider challenge aborted: %w", err)
	}
	if action.kind == challengeActionCancelKind {
		b.host.completeChallenge(record.ID, ChallengeStatusCancelled, "cancelled")
		return errors.New("interactive provider challenge was cancelled")
	}

	b.host.completeChallenge(record.ID, ChallengeStatusCompleted, "continued")
	return nil
}

func (b *challengeBroker) Continue(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
	if challenge == nil {
		return nil, errors.New("interactive provider challenge is required")
	}

	completionMode, _, _ := challengeContractMetadataFromProviderMetadata(
		challenge,
		b.host.challengeMetadata(challenge),
	)
	if completionMode == ChallengeCompletionModeOwnedBrowserObserved {
		record := b.host.buildChallengeRecord(
			b.host.newID(),
			b.sessionID,
			"",
			challenge,
		)
		b.host.recordChallenge(b.sessionID, record)

		action, err := b.host.waitChallengeAction(ctx, record.ID)
		if err != nil {
			b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
			return nil, fmt.Errorf("interactive provider challenge aborted: %w", err)
		}
		if action.kind == challengeActionCancelKind {
			b.host.completeChallenge(record.ID, ChallengeStatusCancelled, "cancelled")
			return nil, errors.New("interactive provider challenge was cancelled")
		}

		result, err := browserContinuationFromChallengeAction(
			ctx,
			challenge,
			action,
		)
		if err != nil {
			b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
			return nil, err
		}

		b.host.completeChallenge(record.ID, ChallengeStatusCompleted, "completed")
		return result, nil
	}

	continuation, err := b.host.startContinuation(ctx, challenge)
	if err != nil {
		return nil, err
	}
	defer func() {
		_ = continuation.Close()
	}()

	record := b.host.buildChallengeRecord(
		b.host.newID(),
		b.sessionID,
		"",
		challenge,
	)
	b.host.recordChallenge(b.sessionID, record)

	action, err := b.host.waitChallengeAction(ctx, record.ID)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return nil, fmt.Errorf("interactive provider challenge aborted: %w", err)
	}
	if action.kind == challengeActionCancelKind {
		b.host.completeChallenge(record.ID, ChallengeStatusCancelled, "cancelled")
		return nil, errors.New("interactive provider challenge was cancelled")
	}

	result, err := continuation.Complete(ctx)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return nil, err
	}

	b.host.completeChallenge(record.ID, ChallengeStatusCompleted, "completed")
	return result, nil
}

func (h *Host) normalizeProfileSpec(
	spec ProfileSpec,
	mode providerSettingsValidationMode,
) (ProfileSpec, error) {
	spec.Provider = strings.TrimSpace(spec.Provider)
	spec.Link = strings.TrimSpace(spec.Link)
	spec.ProviderSettings = cloneProviderSettings(spec.ProviderSettings)
	spec.ListenAddr = strings.TrimSpace(spec.ListenAddr)
	spec.PeerAddr = strings.TrimSpace(spec.PeerAddr)
	spec.Ingress = normalizeAdapterKind(spec.Ingress)
	spec.TURNServer = strings.TrimSpace(spec.TURNServer)
	spec.TURNPort = strings.TrimSpace(spec.TURNPort)
	spec.BindInterface = strings.TrimSpace(spec.BindInterface)
	spec.LogLevel = strings.TrimSpace(spec.LogLevel)
	if spec.Connections <= 0 {
		spec.Connections = 1
	}
	if spec.Mode == "" {
		spec.Mode = TransportModeAuto
	}
	if spec.UseDTLS == nil {
		useDTLS := true
		spec.UseDTLS = &useDTLS
	}

	if spec.Provider != "" {
		descriptor, err := h.providerDescriptor(spec.Provider)
		if err != nil {
			return ProfileSpec{}, err
		}
		settings, err := normalizeProviderSettingsForDescriptor(
			descriptor,
			spec.ProviderSettings,
			mode,
		)
		if err != nil {
			return ProfileSpec{}, err
		}
		spec.ProviderSettings = settings
	} else if len(spec.ProviderSettings) > 0 {
		return ProfileSpec{}, providerSettingsValidationError(
			firstProviderSettingsKey(spec.ProviderSettings),
			providerSettingsViolationUnknown,
			"provider_settings require a provider",
		)
	}

	if mode == providerSettingsModePersistedProfile {
		return normalizePersistedProfileSpec(spec)
	}

	return normalizeRuntimeProfileSpec(spec)
}

func normalizePersistedProfileSpec(spec ProfileSpec) (ProfileSpec, error) {
	cfg := translateProfileSpec(spec)
	if strings.TrimSpace(cfg.Link) == "" {
		// Persisted GUI state intentionally strips secret-bearing links. Keep
		// validating the rest of the transport policy without requiring the
		// redacted secret to be present in local plaintext storage.
		cfg.Link = "persisted-profile://redacted"
	}
	if err := session.ValidatePolicy(cfg); err != nil {
		return ProfileSpec{}, err
	}
	return spec, nil
}

func normalizeRuntimeProfileSpec(spec ProfileSpec) (ProfileSpec, error) {
	cfg := translateProfileSpec(spec)
	if err := session.ValidatePolicy(cfg); err != nil {
		return ProfileSpec{}, err
	}
	return spec, nil
}

func translateProfileSpec(spec ProfileSpec) config.ClientConfig {
	useDTLS := true
	if spec.UseDTLS != nil {
		useDTLS = *spec.UseDTLS
	}

	mode := config.TransportMode(spec.Mode)
	if mode == "" {
		mode = config.TransportModeAuto
	}
	return config.ClientConfig{
		Provider:         spec.Provider,
		Link:             spec.Link,
		ProviderSettings: cloneProviderSettings(spec.ProviderSettings),
		ListenAddr:       spec.ListenAddr,
		PeerAddr:         spec.PeerAddr,
		Ingress:          config.AdapterKind(spec.Ingress),
		Connections:      spec.Connections,
		TURNServer:       spec.TURNServer,
		TURNPort:         spec.TURNPort,
		BindInterface:    spec.BindInterface,
		Mode:             mode,
		UseDTLS:          useDTLS,
	}
}

func (h *Host) redactProfileSpecForOrdinaryRead(spec ProfileSpec) ProfileSpec {
	settings := cloneProviderSettings(spec.ProviderSettings)
	spec.ProviderSettings = nil
	if strings.TrimSpace(spec.Provider) == "" {
		return spec
	}

	descriptor, err := h.providerDescriptor(spec.Provider)
	if err != nil {
		return spec
	}
	spec.ProviderSettings = redactProviderSettingsForOrdinaryRead(
		descriptor,
		settings,
	)
	return spec
}

func normalizeAdapterKind(kind AdapterKind) AdapterKind {
	switch AdapterKind(strings.TrimSpace(string(kind))) {
	case "", AdapterUDP:
		return AdapterUDP
	case AdapterTCP:
		return AdapterTCP
	default:
		return kind
	}
}

func appendWithLimit[T any](items []T, item T, limit int) []T {
	items = append(items, item)
	if limit > 0 && len(items) > limit {
		copy(items, items[len(items)-limit:])
		items = items[:limit]
	}
	return items
}

func replaceChallenge(challenges []Challenge, update Challenge) []Challenge {
	for i := range challenges {
		if challenges[i].ID == update.ID {
			challenges[i] = update
			return challenges
		}
	}
	return append(challenges, update)
}

func snapshotEvent(snapshot Session, eventType EventType, stage string, message string) Event {
	return Event{
		Timestamp: snapshot.UpdatedAt,
		SessionID: snapshot.ID,
		Type:      eventType,
		State:     snapshot.State,
		Stage:     stage,
		Message:   message,
	}
}

func missingCapabilities(have []Capability, want []Capability) []Capability {
	if len(want) == 0 {
		return nil
	}
	seen := make(map[Capability]struct{}, len(have))
	for _, capability := range have {
		seen[capability] = struct{}{}
	}
	var missing []Capability
	for _, capability := range want {
		if _, ok := seen[capability]; !ok {
			missing = append(missing, capability)
		}
	}
	sort.Slice(missing, func(i, j int) bool { return missing[i] < missing[j] })
	return missing
}

func joinCapabilities(values []Capability) string {
	if len(values) == 0 {
		return ""
	}
	out := make([]string, 0, len(values))
	for _, value := range values {
		out = append(out, string(value))
	}
	sort.Strings(out)
	return strings.Join(out, ",")
}

func stringValue(value any) string {
	switch typed := value.(type) {
	case string:
		return typed
	case fmt.Stringer:
		return typed.String()
	case nil:
		return ""
	default:
		return fmt.Sprint(typed)
	}
}

func intValue(value any) int {
	switch typed := value.(type) {
	case int:
		return typed
	case int64:
		return int(typed)
	case uint64:
		return int(typed)
	default:
		return 0
	}
}

func cloneChallenge(challenge *Challenge) *Challenge {
	if challenge == nil {
		return nil
	}
	copyChallenge := *challenge
	return &copyChallenge
}
