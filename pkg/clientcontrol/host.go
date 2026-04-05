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
	ErrProfileNotFound   = errors.New("client control profile not found")
	ErrSessionNotFound   = errors.New("client control session not found")
	ErrChallengeNotFound = errors.New("client control challenge not found")
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
	logger            *slog.Logger
	registry          *provider.Registry
	now               func() time.Time
	newID             func() string
	newSessionID      func() string
	newRunner         session.RunnerFactory
	startContinuation func(context.Context, provider.InteractiveChallenge) (browserContinuation, error)
	historyLimit      int
	mode              challengeMode
	cliStdin          io.Reader
	cliStderr         io.Writer
	promptOpts        providerprompt.Options
}

type Host struct {
	mu                sync.Mutex
	logger            *slog.Logger
	registry          *provider.Registry
	now               func() time.Time
	newID             func() string
	newSessionID      func() string
	newRunner         session.RunnerFactory
	startContinuation func(context.Context, provider.InteractiveChallenge) (browserContinuation, error)
	historyLimit      int
	mode              challengeMode
	cliStdin          io.Reader
	cliStderr         io.Writer
	promptOpts        providerprompt.Options

	profiles    map[string]Profile
	sessions    map[string]*managedSession
	challenges  map[string]*managedChallenge
	subscribers map[uint64]chan Event
	nextSubID   uint64
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
}

type managedChallenge struct {
	snapshot Challenge
	actionCh chan challengeAction
}

type browserContinuation interface {
	Complete(context.Context) (*provider.BrowserContinuation, error)
	Close() error
}

type challengeAction int

const (
	challengeActionContinue challengeAction = iota + 1
	challengeActionCancel
)

func New(opts ...Option) *Host {
	cfg := hostConfig{
		logger:            slog.Default(),
		registry:          provider.NewRegistry(genericturn.New(), vk.New()),
		now:               time.Now,
		newID:             observe.NewSessionID,
		newSessionID:      observe.NewSessionID,
		newRunner:         nil,
		startContinuation: nil,
		historyLimit:      defaultHistoryLimit,
		mode:              challengeModeControlPlane,
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
	if cfg.historyLimit <= 0 {
		cfg.historyLimit = defaultHistoryLimit
	}
	if cfg.startContinuation == nil {
		cfg.startContinuation = func(ctx context.Context, challenge provider.InteractiveChallenge) (browserContinuation, error) {
			return providerprompt.StartContinuation(ctx, challenge, cfg.promptOpts)
		}
	}

	return &Host{
		logger:            cfg.logger,
		registry:          cfg.registry,
		now:               cfg.now,
		newID:             cfg.newID,
		newSessionID:      cfg.newSessionID,
		newRunner:         cfg.newRunner,
		startContinuation: cfg.startContinuation,
		historyLimit:      cfg.historyLimit,
		mode:              cfg.mode,
		cliStdin:          cfg.cliStdin,
		cliStderr:         cfg.cliStderr,
		promptOpts:        cfg.promptOpts,
		profiles:          make(map[string]Profile),
		sessions:          make(map[string]*managedSession),
		challenges:        make(map[string]*managedChallenge),
		subscribers:       make(map[uint64]chan Event),
	}
}

func WithLogger(logger *slog.Logger) Option {
	return func(cfg *hostConfig) {
		cfg.logger = logger
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

func (h *Host) Info() HostInfo {
	return HostInfo{
		Version: ContractVersion,
		Capabilities: []Capability{
			CapabilityChallenges,
			CapabilityDesktopSidecar,
			CapabilityDiagnostics,
			CapabilityEventStream,
			CapabilityMobileHostBridge,
			CapabilityProfiles,
			CapabilitySessions,
		},
	}
}

func (h *Host) Negotiate(req NegotiateRequest) (HostInfo, error) {
	info := h.Info()
	if len(req.SupportedVersions) > 0 {
		compatible := false
		for _, version := range req.SupportedVersions {
			if strings.TrimSpace(version) == info.Version {
				compatible = true
				break
			}
		}
		if !compatible {
			return HostInfo{}, &IncompatibleHostError{
				Version:           info.Version,
				SupportedVersions: append([]string(nil), req.SupportedVersions...),
			}
		}
	}

	missing := missingCapabilities(info.Capabilities, req.RequiredCapabilities)
	if len(missing) > 0 {
		return HostInfo{}, &IncompatibleHostError{
			Version:             info.Version,
			MissingCapabilities: missing,
		}
	}

	return info, nil
}

func (h *Host) UpsertProfile(profile Profile) (Profile, error) {
	spec, err := normalizeProfileSpec(profile.Spec)
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
	startedAt := h.now().UTC()
	sessionID, err := h.allocateSessionID()
	if err != nil {
		return Session{}, err
	}
	snapshot := Session{
		ID:          sessionID,
		ProfileID:   profileID,
		ProfileName: profileName,
		Profile:     spec,
		State:       SessionStateStarting,
		StartedAt:   startedAt,
		UpdatedAt:   startedAt,
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

func (h *Host) StopSession(sessionID string) (Session, error) {
	h.mu.Lock()
	managed, ok := h.sessions[sessionID]
	if !ok {
		h.mu.Unlock()
		return Session{}, ErrSessionNotFound
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
	return h.signalChallenge(challengeID, challengeActionContinue, ChallengeStatusContinuing)
}

func (h *Host) CancelChallenge(challengeID string) (Challenge, error) {
	return h.signalChallenge(challengeID, challengeActionCancel, ChallengeStatusCancelled)
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
		Session:    managed.snapshot,
		Events:     events,
		Challenges: challenges,
		Metrics:    managed.metrics.Prometheus(),
	}, nil
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
		spec, err := normalizeProfileSpec(*req.Spec)
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
	spec, err := normalizeProfileSpec(profile.Spec)
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
	if managedSession, ok := h.sessions[sessionID]; ok {
		managedSession.snapshot.ActiveChallengeID = ""
		if status == ChallengeStatusCompleted {
			managedSession.snapshot.State = SessionStateStarting
		}
		managedSession.snapshot.UpdatedAt = challenge.UpdatedAt
		managedSession.challenges = replaceChallenge(managedSession.challenges, challenge)
		managedSession.events = appendWithLimit(managedSession.events, Event{
			ID:        h.newID(),
			Timestamp: challenge.UpdatedAt,
			SessionID: sessionID,
			Type:      EventChallengeUpdated,
			State:     managedSession.snapshot.State,
			Message:   message,
			Challenge: cloneChallenge(&challenge),
		}, h.historyLimit)
	}
	h.mu.Unlock()

	h.publishEvent(Event{
		ID:        h.newID(),
		Timestamp: challenge.UpdatedAt,
		SessionID: sessionID,
		Type:      EventChallengeUpdated,
		Message:   message,
		Challenge: cloneChallenge(&challenge),
	})
}

func (h *Host) waitChallengeAction(ctx context.Context, challengeID string) (challengeAction, error) {
	h.mu.Lock()
	managed, ok := h.challenges[challengeID]
	h.mu.Unlock()
	if !ok {
		return 0, ErrChallengeNotFound
	}

	select {
	case <-ctx.Done():
		return 0, ctx.Err()
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
	managed.snapshot.Status = status
	managed.snapshot.UpdatedAt = h.now().UTC()
	challenge := managed.snapshot
	sessionID := challenge.SessionID
	if managedSession, ok := h.sessions[sessionID]; ok {
		managedSession.challenges = replaceChallenge(managedSession.challenges, challenge)
	}
	actionCh := managed.actionCh
	h.mu.Unlock()

	select {
	case actionCh <- action:
	default:
	}

	event := Event{
		ID:        h.newID(),
		Timestamp: challenge.UpdatedAt,
		SessionID: sessionID,
		Type:      EventChallengeUpdated,
		Challenge: cloneChallenge(&challenge),
	}
	h.mu.Lock()
	if managedSession, ok := h.sessions[sessionID]; ok {
		managedSession.events = appendWithLimit(managedSession.events, event, h.historyLimit)
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

	record := Challenge{
		ID:        b.host.newID(),
		SessionID: b.sessionID,
		Provider:  challenge.ProviderName(),
		Stage:     challenge.StageName(),
		Kind:      challenge.Kind(),
		Prompt:    providerprompt.ContinuationPrompt(challenge),
		OpenURL:   providerprompt.ContinuationOpenURL(challenge),
		Status:    ChallengeStatusPending,
		CreatedAt: b.host.now().UTC(),
		UpdatedAt: b.host.now().UTC(),
	}
	b.host.recordChallenge(b.sessionID, record)

	action, err := b.host.waitChallengeAction(ctx, record.ID)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return fmt.Errorf("interactive provider challenge aborted: %w", err)
	}
	if action == challengeActionCancel {
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

	continuation, err := b.host.startContinuation(ctx, challenge)
	if err != nil {
		return nil, err
	}
	defer func() {
		_ = continuation.Close()
	}()

	record := Challenge{
		ID:        b.host.newID(),
		SessionID: b.sessionID,
		Provider:  challenge.ProviderName(),
		Stage:     challenge.StageName(),
		Kind:      challenge.Kind(),
		Prompt:    providerprompt.ContinuationPrompt(challenge),
		OpenURL:   providerprompt.ContinuationOpenURL(challenge),
		Status:    ChallengeStatusPending,
		CreatedAt: b.host.now().UTC(),
		UpdatedAt: b.host.now().UTC(),
	}
	b.host.recordChallenge(b.sessionID, record)

	action, err := b.host.waitChallengeAction(ctx, record.ID)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return nil, fmt.Errorf("interactive provider challenge aborted: %w", err)
	}
	if action == challengeActionCancel {
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

func normalizeProfileSpec(spec ProfileSpec) (ProfileSpec, error) {
	spec.Provider = strings.TrimSpace(spec.Provider)
	spec.Link = strings.TrimSpace(spec.Link)
	spec.ListenAddr = strings.TrimSpace(spec.ListenAddr)
	spec.PeerAddr = strings.TrimSpace(spec.PeerAddr)
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

	cfg := translateProfileSpec(spec)
	if err := cfg.Validate(); err != nil {
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
		Provider:      spec.Provider,
		Link:          spec.Link,
		ListenAddr:    spec.ListenAddr,
		PeerAddr:      spec.PeerAddr,
		Connections:   spec.Connections,
		TURNServer:    spec.TURNServer,
		TURNPort:      spec.TURNPort,
		BindInterface: spec.BindInterface,
		Mode:          mode,
		UseDTLS:       useDTLS,
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
