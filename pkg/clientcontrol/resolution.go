package clientcontrol

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/providerprompt"
)

const (
	resolutionExpirySourceMetadataKey    = "turn_credential_expiry_source"
	resolutionExpiryTimestampMetadataKey = "turn_credential_expires_at"
	resolutionExpirySourceProviderTTL    = "provider_credentials_ttl"
	redactedTurnUsername                 = "<redacted:turn-username>"
	redactedTurnPassword                 = "<redacted:turn-password>"
)

var (
	errResolutionExportUnavailable  = errors.New("resolution export is not available")
	errResolutionNotTransportReady  = errors.New("resolution is not transport-ready")
	errResolutionExpired            = errors.New("resolution has expired")
	errInteractiveChallengeCanceled = errors.New("interactive provider challenge was cancelled")
)

type ResolutionActionError struct {
	Action ArtifactAction
	Plan   *RuntimeExecutionPlan
	Err    error
}

func (e *ResolutionActionError) Error() string {
	if e == nil {
		return ""
	}
	if e.Err == nil {
		return fmt.Sprintf("resolution action %q is unavailable", e.Action)
	}
	if e.Plan != nil {
		return fmt.Sprintf(
			"resolution action %q is unavailable for execution plan %s/%s/%s/%s: %v",
			e.Action,
			e.Plan.AccessMethod,
			e.Plan.CarrierFamily,
			e.Plan.EngineFamily,
			e.Plan.HostAdapter,
			e.Err,
		)
	}
	return fmt.Sprintf("resolution action %q is unavailable: %v", e.Action, e.Err)
}

func (e *ResolutionActionError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

type managedResolution struct {
	snapshot   Resolution
	secret     provider.Resolution
	descriptor ProviderDescriptor
	cancel     context.CancelFunc
	done       chan struct{}
	input      StartResolutionRequest
	events     []Event
	challenges []Challenge
}

func (h *Host) StartResolution(ctx context.Context, req StartResolutionRequest) (Resolution, error) {
	req.Provider = strings.TrimSpace(req.Provider)
	if req.Provider == "" {
		return Resolution{}, errors.New("provider is required")
	}
	descriptor, err := h.providerDescriptor(req.Provider)
	if err != nil {
		return Resolution{}, err
	}
	normalized, err := normalizeStartResolutionRequest(req, descriptor)
	if err != nil {
		return Resolution{}, err
	}

	startedAt := h.now().UTC()
	resolutionID, err := h.allocateResolutionID()
	if err != nil {
		return Resolution{}, err
	}
	runCtx, cancel := context.WithCancel(ctx)
	snapshot := Resolution{
		ID:       resolutionID,
		Provider: normalized.Provider,
		Input: ResolutionInput{
			Provider:            normalized.Provider,
			Kind:                normalized.Input.Kind,
			LinkRedacted:        redactResolutionInput(normalized.Provider, normalized.Link),
			InteractiveProvider: normalized.InteractiveProvider,
		},
		State:     ResolutionStateStarting,
		Export:    ResolutionExportStatus{Supported: false},
		StartedAt: startedAt,
		UpdatedAt: startedAt,
	}
	managed := &managedResolution{
		snapshot:   snapshot,
		descriptor: descriptor,
		cancel:     cancel,
		done:       make(chan struct{}),
		input:      normalized,
	}

	startEvent := resolutionSnapshotEvent(snapshot, EventResolutionStarting, "")

	h.mu.Lock()
	managed.events = appendWithLimit(managed.events, startEvent, h.historyLimit)
	h.resolutions[resolutionID] = managed
	h.mu.Unlock()

	h.publishEvent(startEvent)
	go h.runResolution(runCtx, resolutionID)

	return snapshot, nil
}

func (h *Host) Resolution(resolutionID string) (Resolution, error) {
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return Resolution{}, ErrResolutionNotFound
	}
	event := h.expireResolutionLocked(managed)
	snapshot := managed.snapshot
	h.mu.Unlock()

	if event != nil {
		h.publishEvent(*event)
	}
	return snapshot, nil
}

func (h *Host) Resolutions() []Resolution {
	h.mu.Lock()
	out := make([]Resolution, 0, len(h.resolutions))
	events := make([]Event, 0, len(h.resolutions))
	for _, managed := range h.resolutions {
		if event := h.expireResolutionLocked(managed); event != nil {
			events = append(events, *event)
		}
		out = append(out, managed.snapshot)
	}
	h.mu.Unlock()

	for _, event := range events {
		h.publishEvent(event)
	}
	return out
}

func (h *Host) WaitResolution(ctx context.Context, resolutionID string) (Resolution, error) {
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return Resolution{}, ErrResolutionNotFound
	}
	done := managed.done
	h.mu.Unlock()

	select {
	case <-ctx.Done():
		return Resolution{}, ctx.Err()
	case <-done:
		return h.Resolution(resolutionID)
	}
}

func (h *Host) CancelResolution(resolutionID string) (Resolution, error) {
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return Resolution{}, ErrResolutionNotFound
	}
	switch managed.snapshot.State {
	case ResolutionStateResolved, ResolutionStateFailed, ResolutionStateCancelled, ResolutionStateExpired:
		snapshot := managed.snapshot
		h.mu.Unlock()
		return snapshot, nil
	}
	now := h.now().UTC()
	managed.snapshot.State = ResolutionStateCancelled
	managed.snapshot.ActiveChallengeID = ""
	managed.snapshot.UpdatedAt = now
	snapshot := managed.snapshot
	event := resolutionSnapshotEvent(snapshot, EventResolutionCancelled, "cancelled")
	managed.events = appendWithLimit(managed.events, event, h.historyLimit)
	cancel := managed.cancel
	done := managed.done
	select {
	case <-done:
	default:
		close(done)
	}
	h.mu.Unlock()

	h.publishEvent(event)
	cancel()
	return snapshot, nil
}

func (h *Host) ExportResolution(resolutionID string) (ResolutionExportResult, error) {
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return ResolutionExportResult{}, ErrResolutionNotFound
	}
	event := h.expireResolutionLocked(managed)
	snapshot := managed.snapshot
	secret := managed.secret
	h.mu.Unlock()

	if event != nil {
		h.publishEvent(*event)
	}

	if snapshot.State == ResolutionStateExpired {
		return ResolutionExportResult{}, errResolutionExpired
	}
	if snapshot.State != ResolutionStateResolved {
		return ResolutionExportResult{}, errResolutionNotTransportReady
	}
	if !resolutionSupportsAction(snapshot, ArtifactActionExportHandoff) {
		return ResolutionExportResult{}, &ResolutionActionError{
			Action: ArtifactActionExportHandoff,
			Err:    errResolutionExportUnavailable,
		}
	}
	if !snapshot.Export.Supported || snapshot.Export.ExpiresAt == nil {
		return ResolutionExportResult{}, errResolutionExportUnavailable
	}

	link := genericturn.FormatLink(secret.Credentials)
	if link == "" {
		return ResolutionExportResult{}, errResolutionExportUnavailable
	}

	return ResolutionExportResult{
		ResolutionID: snapshot.ID,
		Link:         link,
		ExpiresAt:    snapshot.Export.ExpiresAt.UTC(),
		ExpirySource: snapshot.Export.ExpirySource,
	}, nil
}

func (h *Host) MaterializeResolution(ctx context.Context, resolutionID string, defaults RuntimeDefaults) (Session, error) {
	return h.MaterializeResolutionWithPlan(ctx, resolutionID, defaults, nil)
}

func (h *Host) MaterializeResolutionWithPlan(
	ctx context.Context,
	resolutionID string,
	defaults RuntimeDefaults,
	requestedPlan *RuntimeExecutionPlan,
) (Session, error) {
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return Session{}, ErrResolutionNotFound
	}
	event := h.expireResolutionLocked(managed)
	snapshot := managed.snapshot
	secret := managed.secret
	h.mu.Unlock()

	if event != nil {
		h.publishEvent(*event)
	}

	if snapshot.State == ResolutionStateExpired {
		return Session{}, errResolutionExpired
	}
	if snapshot.State != ResolutionStateResolved {
		return Session{}, errResolutionNotTransportReady
	}
	if !resolutionSupportsAction(snapshot, ArtifactActionStartOnThisDevice) {
		return Session{}, &ResolutionActionError{
			Action: ArtifactActionStartOnThisDevice,
			Err:    errResolutionNotTransportReady,
		}
	}
	selectedPlan, err := selectResolutionExecutionPlan(snapshot, ArtifactActionStartOnThisDevice, requestedPlan)
	if err != nil {
		return Session{}, &ResolutionActionError{
			Action: ArtifactActionStartOnThisDevice,
			Plan:   cloneRuntimeExecutionPlan(requestedPlan),
			Err:    err,
		}
	}
	if selectedPlan.Plan.EngineFamily != RuntimeEngineFamilyCustomPacketOverlay ||
		selectedPlan.Plan.CarrierFamily != RuntimeCarrierFamilyTURNDTLSOverlay ||
		selectedPlan.Plan.AccessMethod != RuntimeAccessMethodTURNCredentials ||
		strings.TrimSpace(string(selectedPlan.Plan.HostAdapter)) != "" {
		return Session{}, &ResolutionActionError{
			Action: ArtifactActionStartOnThisDevice,
			Plan:   cloneRuntimeExecutionPlan(&selectedPlan.Plan),
			Err:    fmt.Errorf("%w: host runtime does not yet implement the requested execution plan", errRuntimeExecutionPlanUnavailable),
		}
	}

	spec, err := buildMaterializedProfileSpec(secret.Credentials, defaults)
	if err != nil {
		return Session{}, err
	}
	return h.startSessionFromSpec(ctx, "", "", spec, resolutionID)
}

func (h *Host) runResolution(ctx context.Context, resolutionID string) {
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return
	}
	req := managed.input
	h.mu.Unlock()

	adapter, err := h.registry.Get(req.Provider)
	if err != nil {
		h.finishResolutionFailure(resolutionID, err)
		return
	}

	runCtx := ctx
	if req.InteractiveProvider {
		switch h.mode {
		case challengeModeCLI:
			handler := providerprompt.NewHandler(h.cliStdin, h.cliStderr, h.promptOpts)
			runCtx = provider.WithInteractionHandler(runCtx, handler)
			runCtx = provider.WithBrowserContinuationHandler(runCtx, handler)
		default:
			broker := &resolutionChallengeBroker{host: h, resolutionID: resolutionID}
			runCtx = provider.WithInteractionHandler(runCtx, broker)
			runCtx = provider.WithBrowserContinuationHandler(runCtx, broker)
		}
	}
	if len(req.ProviderSettings) > 0 {
		runCtx = provider.WithSettings(
			runCtx,
			provider.ProviderSettings(req.ProviderSettings),
		)
	}

	resolution, err := adapter.Resolve(runCtx, req.Link)
	if err != nil {
		h.finishResolutionFailure(resolutionID, err)
		return
	}
	h.finishResolutionSuccess(resolutionID, resolution)
}

func (h *Host) finishResolutionSuccess(resolutionID string, resolved provider.Resolution) {
	now := h.now().UTC()
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return
	}
	switch managed.snapshot.State {
	case ResolutionStateCancelled, ResolutionStateFailed, ResolutionStateExpired:
		h.mu.Unlock()
		return
	}
	credentials, export, artifact, err := resolvedSnapshotContract(managed.descriptor, resolved, now, h.platformTunnels)
	if err != nil {
		h.mu.Unlock()
		h.finishResolutionFailure(resolutionID, err)
		return
	}
	managed.secret = resolved
	managed.snapshot.Provider = firstNonEmpty(strings.TrimSpace(resolved.Metadata["provider"]), managed.snapshot.Provider)
	managed.snapshot.ResolutionMethod = strings.TrimSpace(resolved.Metadata["resolution_method"])
	managed.snapshot.Input.LinkRedacted = firstNonEmpty(redactedLinkFromArtifact(resolved.Artifact), managed.snapshot.Input.LinkRedacted)
	managed.snapshot.Credentials = credentials
	managed.snapshot.Export = export
	managed.snapshot.Artifact = artifact
	managed.snapshot.State = ResolutionStateResolved
	managed.snapshot.ActiveChallengeID = ""
	managed.snapshot.UpdatedAt = now
	managed.snapshot.ResolvedAt = &now
	if managed.snapshot.Export.ExpiresAt != nil && !managed.snapshot.Export.ExpiresAt.After(now) {
		managed.snapshot.State = ResolutionStateExpired
		managed.snapshot.Export.Supported = false
		if managed.snapshot.Artifact != nil {
			managed.snapshot.Artifact.Actions = nil
		}
		managed.snapshot.ExpiredAt = &now
		managed.secret = provider.Resolution{}
	}
	snapshot := managed.snapshot
	eventType := EventResolutionResolved
	message := ""
	if snapshot.State == ResolutionStateExpired {
		eventType = EventResolutionExpired
		message = "expired"
	}
	event := resolutionSnapshotEvent(snapshot, eventType, message)
	managed.events = appendWithLimit(managed.events, event, h.historyLimit)
	done := managed.done
	select {
	case <-done:
	default:
		close(done)
	}
	h.mu.Unlock()

	h.publishEvent(event)
}

func resolvedSnapshotContract(
	descriptor ProviderDescriptor,
	resolved provider.Resolution,
	now time.Time,
	platformTunnels []PlatformTunnelCapability,
) (*ResolutionCredentials, ResolutionExportStatus, *ResolutionArtifact, error) {
	family := resolutionArtifactFamily(descriptor, resolved)
	if family == "" {
		return nil, ResolutionExportStatus{}, nil, errors.New("provider resolution returned no supported runtime artifact")
	}

	switch family {
	case ArtifactFamilyGenericTURN:
		if !hasTransportReadyTURNCredentials(resolved) {
			return nil, ResolutionExportStatus{}, nil, errors.New("provider resolution returned incomplete TURN credentials")
		}
		export := resolutionExportStatus(resolved, now)
		artifact := resolutionArtifactFromResolution(descriptor, resolved, export, platformTunnels)
		if artifact == nil {
			return nil, ResolutionExportStatus{}, nil, errors.New("provider resolution returned incomplete generic_turn runtime artifact")
		}
		return redactedResolutionCredentials(resolved), export, artifact, nil
	case ArtifactFamilyConferenceRoom:
		artifact := resolutionArtifactFromResolution(descriptor, resolved, ResolutionExportStatus{}, platformTunnels)
		if artifact == nil {
			return nil, ResolutionExportStatus{}, nil, errors.New("provider resolution returned incomplete conference_room runtime artifact")
		}
		return nil, ResolutionExportStatus{Supported: false}, artifact, nil
	case ArtifactFamilyCameraStream:
		artifact := resolutionArtifactFromResolution(descriptor, resolved, ResolutionExportStatus{}, platformTunnels)
		if artifact == nil {
			return nil, ResolutionExportStatus{}, nil, errors.New("provider resolution returned incomplete camera_stream runtime artifact")
		}
		return nil, ResolutionExportStatus{Supported: false}, artifact, nil
	default:
		return nil, ResolutionExportStatus{}, nil, fmt.Errorf("provider resolution returned unsupported artifact family %q", family)
	}
}

func (h *Host) finishResolutionFailure(resolutionID string, err error) {
	now := h.now().UTC()
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return
	}
	eventType := EventResolutionFailed
	message := redactedResolutionErrorMessage(err)
	if managed.snapshot.State != ResolutionStateCancelled {
		switch {
		case errors.Is(err, context.Canceled), errors.Is(err, errInteractiveChallengeCanceled):
			managed.snapshot.State = ResolutionStateCancelled
			eventType = EventResolutionCancelled
			message = "cancelled"
		default:
			managed.snapshot.State = ResolutionStateFailed
			managed.snapshot.Failure = failureInfoFromResolutionError(err)
		}
	}
	managed.snapshot.ActiveChallengeID = ""
	managed.snapshot.UpdatedAt = now
	snapshot := managed.snapshot
	done := managed.done
	alreadyClosed := false
	select {
	case <-done:
		alreadyClosed = true
	default:
	}
	event := resolutionSnapshotEvent(snapshot, eventType, message)
	if !alreadyClosed {
		managed.events = appendWithLimit(managed.events, event, h.historyLimit)
		close(done)
	}
	h.mu.Unlock()

	if !alreadyClosed {
		h.publishEvent(event)
	}
}

func (h *Host) allocateResolutionID() (string, error) {
	for attempts := 0; attempts < 8; attempts++ {
		candidate := strings.TrimSpace(h.newID())
		if candidate == "" {
			continue
		}
		h.mu.Lock()
		_, exists := h.resolutions[candidate]
		h.mu.Unlock()
		if !exists {
			return candidate, nil
		}
	}
	return "", errors.New("client control resolution id allocation failed")
}

func (h *Host) expireResolutionLocked(managed *managedResolution) *Event {
	if managed == nil || managed.snapshot.State != ResolutionStateResolved || managed.snapshot.Export.ExpiresAt == nil {
		return nil
	}
	now := h.now().UTC()
	if managed.snapshot.Export.ExpiresAt.After(now) {
		return nil
	}
	managed.snapshot.State = ResolutionStateExpired
	managed.snapshot.Export.Supported = false
	managed.snapshot.ActiveChallengeID = ""
	managed.snapshot.UpdatedAt = now
	managed.snapshot.ExpiredAt = &now
	if managed.snapshot.Artifact != nil {
		managed.snapshot.Artifact.Actions = nil
	}
	managed.secret = provider.Resolution{}
	event := resolutionSnapshotEvent(managed.snapshot, EventResolutionExpired, "expired")
	managed.events = appendWithLimit(managed.events, event, h.historyLimit)
	return &event
}

type resolutionChallengeBroker struct {
	host         *Host
	resolutionID string
}

func (b *resolutionChallengeBroker) Handle(ctx context.Context, challenge provider.InteractiveChallenge) error {
	if challenge == nil {
		return errors.New("interactive provider challenge is required")
	}

	record := b.host.buildChallengeRecord(
		b.host.newID(),
		"",
		b.resolutionID,
		challenge,
	)
	b.host.recordResolutionChallenge(b.resolutionID, record)

	action, err := b.host.waitChallengeAction(ctx, record.ID)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return fmt.Errorf("interactive provider challenge aborted: %w", err)
	}
	if action.kind == challengeActionCancelKind {
		b.host.completeChallenge(record.ID, ChallengeStatusCancelled, "cancelled")
		return errInteractiveChallengeCanceled
	}

	b.host.completeChallenge(record.ID, ChallengeStatusCompleted, "continued")
	return nil
}

func (b *resolutionChallengeBroker) Continue(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
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
			"",
			b.resolutionID,
			challenge,
		)
		b.host.recordResolutionChallenge(b.resolutionID, record)

		action, err := b.host.waitChallengeAction(ctx, record.ID)
		if err != nil {
			b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
			return nil, fmt.Errorf("interactive provider challenge aborted: %w", err)
		}
		if action.kind == challengeActionCancelKind {
			b.host.completeChallenge(record.ID, ChallengeStatusCancelled, "cancelled")
			return nil, errInteractiveChallengeCanceled
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
		"",
		b.resolutionID,
		challenge,
	)
	b.host.recordResolutionChallenge(b.resolutionID, record)

	action, err := b.host.waitChallengeAction(ctx, record.ID)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return nil, fmt.Errorf("interactive provider challenge aborted: %w", err)
	}
	if action.kind == challengeActionCancelKind {
		b.host.completeChallenge(record.ID, ChallengeStatusCancelled, "cancelled")
		return nil, errInteractiveChallengeCanceled
	}

	result, err := continuation.Complete(ctx)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return nil, err
	}

	b.host.completeChallenge(record.ID, ChallengeStatusCompleted, "completed")
	return result, nil
}

func (h *Host) recordResolutionChallenge(resolutionID string, challenge Challenge) {
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return
	}
	managed.snapshot.State = ResolutionStateChallengeRequired
	managed.snapshot.ActiveChallengeID = challenge.ID
	managed.snapshot.UpdatedAt = challenge.UpdatedAt
	managed.challenges = appendWithLimit(managed.challenges, challenge, h.historyLimit)
	h.challenges[challenge.ID] = &managedChallenge{
		snapshot: challenge,
		actionCh: make(chan challengeAction, 1),
	}
	event := Event{
		ID:              h.newID(),
		Timestamp:       challenge.CreatedAt,
		ResolutionID:    resolutionID,
		Type:            EventChallengeRequired,
		ResolutionState: ResolutionStateChallengeRequired,
		Challenge:       cloneChallenge(&challenge),
	}
	managed.events = appendWithLimit(managed.events, event, h.historyLimit)
	h.mu.Unlock()

	h.publishEvent(event)
}

func (h *Host) providerDescriptor(providerID string) (ProviderDescriptor, error) {
	internalDescriptor, err := h.registry.Descriptor(providerID)
	if err != nil {
		return ProviderDescriptor{}, err
	}
	descriptor, schemaErr := providerDescriptorFromInternal(internalDescriptor)
	if schemaErr != nil {
		h.logger.Warn(
			"provider advertised invalid provider_settings_schema; omitting schema",
			"provider", internalDescriptor.ID,
			"error", schemaErr,
		)
	}
	return descriptor, nil
}

func normalizeStartResolutionRequest(req StartResolutionRequest, descriptor ProviderDescriptor) (StartResolutionRequest, error) {
	req.Provider = strings.TrimSpace(req.Provider)
	req.InteractiveProvider = providerMayRequireInteractiveSupport(descriptor)
	req.ProviderSettings = cloneProviderSettings(req.ProviderSettings)

	if req.Input == nil {
		return StartResolutionRequest{}, errors.New("input is required")
	}

	normalizedInput, err := normalizeProviderInputEnvelope(*req.Input)
	if err != nil {
		return StartResolutionRequest{}, err
	}
	if normalizedInput.Kind != descriptor.InputKind {
		return StartResolutionRequest{}, fmt.Errorf("provider %q expects input kind %q, got %q", req.Provider, descriptor.InputKind, normalizedInput.Kind)
	}
	switch normalizedInput.Kind {
	case ProviderInputKindLink:
		if normalizedInput.Link == "" {
			return StartResolutionRequest{}, errors.New("input.link is required")
		}
		settings, err := normalizeProviderSettingsForDescriptor(
			descriptor,
			req.ProviderSettings,
			providerSettingsModeImmediate,
		)
		if err != nil {
			return StartResolutionRequest{}, err
		}
		req.Input = &normalizedInput
		req.Link = normalizedInput.Link
		req.ProviderSettings = settings
		return req, nil
	default:
		return StartResolutionRequest{}, fmt.Errorf("provider input kind %q is not supported by this host", normalizedInput.Kind)
	}
}

func normalizeProviderInputEnvelope(input ProviderInputEnvelope) (ProviderInputEnvelope, error) {
	input.Kind = ProviderInputKind(strings.TrimSpace(string(input.Kind)))
	input.Link = strings.TrimSpace(input.Link)
	if strings.TrimSpace(string(input.Kind)) == "" {
		return ProviderInputEnvelope{}, errors.New("input.kind is required")
	}
	return input, nil
}

func buildMaterializedProfileSpec(credentials provider.Credentials, defaults RuntimeDefaults) (ProfileSpec, error) {
	spec := ProfileSpec{
		Provider:      "generic-turn",
		Link:          genericturn.FormatLink(credentials),
		ListenAddr:    defaults.ListenAddr,
		PeerAddr:      defaults.PeerAddr,
		Ingress:       defaults.Ingress,
		Connections:   defaults.Connections,
		TURNServer:    defaults.TURNServer,
		TURNPort:      defaults.TURNPort,
		BindInterface: defaults.BindInterface,
		Mode:          defaults.Mode,
		UseDTLS:       defaults.UseDTLS,
		LogLevel:      defaults.LogLevel,
	}
	return normalizeRuntimeProfileSpec(spec)
}

func failureInfoFromResolutionError(err error) *FailureInfo {
	info := &FailureInfo{
		Message:        redactedResolutionErrorMessage(err),
		NotImplemented: errors.Is(err, provider.ErrNotImplemented),
	}
	var artifactErr *provider.ArtifactError
	if errors.As(err, &artifactErr) && artifactErr.ProbeArtifact != nil && artifactErr.ProbeArtifact.Outcome.ProviderError != nil {
		info.Stage = artifactErr.ProbeArtifact.Outcome.ProviderError.Stage
	}
	return info
}

func redactedResolutionErrorMessage(err error) string {
	if err == nil {
		return ""
	}

	var artifactErr *provider.ArtifactError
	if errors.As(err, &artifactErr) && artifactErr.ProbeArtifact != nil {
		if providerErr := artifactErr.ProbeArtifact.Outcome.ProviderError; providerErr != nil {
			stage := strings.TrimSpace(providerErr.Stage)
			code := strings.TrimSpace(providerErr.Code)
			switch {
			case stage != "" && code != "":
				return fmt.Sprintf("provider resolution failed at %s [%s]", stage, code)
			case stage != "":
				return fmt.Sprintf("provider resolution failed at %s", stage)
			case code != "":
				return fmt.Sprintf("provider resolution failed [%s]", code)
			}
		}
		return "provider resolution failed"
	}

	return err.Error()
}

func resolutionSnapshotEvent(snapshot Resolution, eventType EventType, message string) Event {
	return Event{
		Timestamp:       snapshot.UpdatedAt,
		ResolutionID:    snapshot.ID,
		Type:            eventType,
		ResolutionState: snapshot.State,
		Message:         message,
		Artifact:        cloneResolutionArtifact(snapshot.Artifact),
	}
}

func resolutionArtifactFromResolution(
	descriptor ProviderDescriptor,
	resolved provider.Resolution,
	export ResolutionExportStatus,
	platformTunnels []PlatformTunnelCapability,
) *ResolutionArtifact {
	family := resolutionArtifactFamily(descriptor, resolved)
	if family == "" {
		return nil
	}
	summary, ok := resolutionArtifactSummary(family, resolved)
	if !ok {
		return nil
	}

	artifact := &ResolutionArtifact{
		Family:        family,
		AccessMethods: resolutionArtifactAccessMethods(family),
		Actions:       resolutionArtifactActions(descriptor, family, export, summary, platformTunnels),
		Summary:       summary,
	}
	return artifact
}

func resolutionArtifactFamily(descriptor ProviderDescriptor, resolved provider.Resolution) ArtifactFamily {
	if hasTransportReadyTURNCredentials(resolved) {
		for _, family := range descriptor.ArtifactFamilies {
			if family == ArtifactFamilyGenericTURN {
				return ArtifactFamilyGenericTURN
			}
		}
		return ArtifactFamilyGenericTURN
	}
	if artifact := resolved.Artifact; artifact != nil {
		switch {
		case artifact.Outcome.ConferenceRoom != nil || strings.TrimSpace(artifact.Outcome.ResultKind) == string(ArtifactFamilyConferenceRoom):
			if providerDescriptorSupportsArtifactFamily(descriptor, ArtifactFamilyConferenceRoom) {
				return ArtifactFamilyConferenceRoom
			}
		case artifact.Outcome.CameraStream != nil || strings.TrimSpace(artifact.Outcome.ResultKind) == string(ArtifactFamilyCameraStream):
			if providerDescriptorSupportsArtifactFamily(descriptor, ArtifactFamilyCameraStream) {
				return ArtifactFamilyCameraStream
			}
		}
	}
	if len(descriptor.ArtifactFamilies) == 1 {
		return descriptor.ArtifactFamilies[0]
	}
	return ""
}

func resolutionArtifactSummary(family ArtifactFamily, resolved provider.Resolution) (ResolutionArtifactSummary, bool) {
	summary := ResolutionArtifactSummary{}
	switch family {
	case ArtifactFamilyGenericTURN:
		summary.GenericTURN = cloneResolutionCredentials(redactedResolutionCredentials(resolved))
		return summary, summary.GenericTURN != nil
	case ArtifactFamilyConferenceRoom:
		if resolved.Artifact == nil || resolved.Artifact.Outcome.ConferenceRoom == nil {
			return ResolutionArtifactSummary{}, false
		}
		roomURL := strings.TrimSpace(resolved.Artifact.Outcome.ConferenceRoom.RoomURL)
		if roomURL == "" {
			return ResolutionArtifactSummary{}, false
		}
		summary.ConferenceRoom = &ConferenceRoomArtifactSummary{RoomURL: roomURL}
		return summary, true
	case ArtifactFamilyCameraStream:
		if resolved.Artifact == nil || resolved.Artifact.Outcome.CameraStream == nil {
			return ResolutionArtifactSummary{}, false
		}
		cameraURL := strings.TrimSpace(resolved.Artifact.Outcome.CameraStream.CameraURL)
		archiveURL := strings.TrimSpace(resolved.Artifact.Outcome.CameraStream.ArchiveURL)
		if cameraURL == "" && archiveURL == "" {
			return ResolutionArtifactSummary{}, false
		}
		summary.CameraStream = &CameraStreamArtifactSummary{
			CameraURL:  cameraURL,
			ArchiveURL: archiveURL,
		}
		return summary, true
	default:
		return ResolutionArtifactSummary{}, false
	}
}

func resolutionArtifactActions(
	descriptor ProviderDescriptor,
	family ArtifactFamily,
	export ResolutionExportStatus,
	summary ResolutionArtifactSummary,
	platformTunnels []PlatformTunnelCapability,
) []ResolutionAction {
	actions := make([]ResolutionAction, 0, len(descriptor.CapabilityHints.PotentialActions))
	for _, action := range descriptor.CapabilityHints.PotentialActions {
		if !artifactActionSupported(action, family, export, summary) {
			continue
		}
		actions = append(actions, ResolutionAction{
			ID:             action,
			ExecutionOwner: artifactActionExecutionOwner(action),
			ExecutionPlans: resolutionExecutionPlansForAction(action, family, platformTunnels),
		})
	}
	return actions
}

func artifactActionSupported(action ArtifactAction, family ArtifactFamily, export ResolutionExportStatus, summary ResolutionArtifactSummary) bool {
	switch action {
	case ArtifactActionStartOnThisDevice:
		return family == ArtifactFamilyGenericTURN
	case ArtifactActionExportHandoff:
		return family == ArtifactFamilyGenericTURN && export.Supported
	case ArtifactActionOpenRoom:
		return family == ArtifactFamilyConferenceRoom &&
			summary.ConferenceRoom != nil &&
			strings.TrimSpace(summary.ConferenceRoom.RoomURL) != ""
	case ArtifactActionOpenCamera:
		return family == ArtifactFamilyCameraStream &&
			summary.CameraStream != nil &&
			strings.TrimSpace(summary.CameraStream.CameraURL) != ""
	case ArtifactActionOpenArchive:
		return family == ArtifactFamilyCameraStream &&
			summary.CameraStream != nil &&
			strings.TrimSpace(summary.CameraStream.ArchiveURL) != ""
	default:
		return false
	}
}

func providerDescriptorSupportsArtifactFamily(descriptor ProviderDescriptor, family ArtifactFamily) bool {
	for _, candidate := range descriptor.ArtifactFamilies {
		if candidate == family {
			return true
		}
	}
	return false
}

func artifactActionExecutionOwner(action ArtifactAction) ActionExecutionOwner {
	switch action {
	case ArtifactActionStartOnThisDevice, ArtifactActionExportHandoff:
		return ActionExecutionOwnerHost
	case ArtifactActionOpenRoom, ArtifactActionOpenCamera, ArtifactActionOpenArchive:
		return ActionExecutionOwnerShellExternal
	default:
		return ActionExecutionOwnerHost
	}
}

func resolutionSupportsAction(snapshot Resolution, action ArtifactAction) bool {
	if snapshot.Artifact == nil {
		return false
	}
	for _, candidate := range snapshot.Artifact.Actions {
		if candidate.ID == action {
			return true
		}
	}
	return false
}

func selectResolutionExecutionPlan(
	snapshot Resolution,
	action ArtifactAction,
	requested *RuntimeExecutionPlan,
) (*RuntimeExecutionPlanDescriptor, error) {
	if snapshot.Artifact == nil {
		if requested == nil {
			return nil, errRuntimeExecutionPlanUnavailable
		}
		return nil, errRuntimeExecutionPlanUnsupported
	}
	for _, candidate := range snapshot.Artifact.Actions {
		if candidate.ID != action {
			continue
		}
		return selectRuntimeExecutionPlanDescriptor(candidate.ExecutionPlans, requested)
	}
	if requested == nil {
		return nil, errRuntimeExecutionPlanUnavailable
	}
	return nil, errRuntimeExecutionPlanUnsupported
}

func hasTransportReadyTURNCredentials(resolved provider.Resolution) bool {
	return strings.TrimSpace(resolved.Credentials.Username) != "" &&
		strings.TrimSpace(resolved.Credentials.Password) != "" &&
		strings.TrimSpace(resolved.Credentials.Address) != ""
}

func redactedResolutionCredentials(resolved provider.Resolution) *ResolutionCredentials {
	if strings.TrimSpace(resolved.Credentials.Address) == "" {
		return nil
	}
	credentials := &ResolutionCredentials{
		Address:          resolved.Credentials.Address,
		UsernameRedacted: redactedTurnUsername,
		PasswordRedacted: redactedTurnPassword,
	}
	if artifact := resolved.Artifact; artifact != nil && artifact.Outcome.Resolution != nil {
		credentials.UsernameRedacted = firstNonEmpty(artifact.Outcome.Resolution.UsernameRedacted, credentials.UsernameRedacted)
		credentials.PasswordRedacted = firstNonEmpty(artifact.Outcome.Resolution.PasswordRedacted, credentials.PasswordRedacted)
	}
	return credentials
}

func resolutionExportStatus(resolved provider.Resolution, now time.Time) ResolutionExportStatus {
	expiresAt, source := resolutionExpiresAt(resolved, now)
	return ResolutionExportStatus{
		Supported:    expiresAt != nil && expiresAt.After(now.UTC()),
		ExpiresAt:    expiresAt,
		ExpirySource: source,
	}
}

func resolutionExpiresAt(resolved provider.Resolution, now time.Time) (*time.Time, string) {
	if resolved.Metadata != nil {
		if raw := strings.TrimSpace(resolved.Metadata[resolutionExpiryTimestampMetadataKey]); raw != "" {
			if parsed, err := time.Parse(time.RFC3339, raw); err == nil {
				expiresAt := parsed.UTC()
				source := firstNonEmpty(strings.TrimSpace(resolved.Metadata[resolutionExpirySourceMetadataKey]), resolutionExpirySourceProviderTTL)
				return &expiresAt, source
			}
		}
	}
	if resolved.Credentials.TTL <= 0 {
		return nil, ""
	}
	expiresAt := now.UTC().Add(resolved.Credentials.TTL)
	source := resolutionExpirySourceProviderTTL
	if resolved.Metadata != nil {
		source = firstNonEmpty(strings.TrimSpace(resolved.Metadata[resolutionExpirySourceMetadataKey]), source)
	}
	return &expiresAt, source
}

func redactedLinkFromArtifact(artifact *provider.ProbeArtifact) string {
	if artifact == nil {
		return ""
	}
	if artifact.Input.LinkRedacted != "" {
		return artifact.Input.LinkRedacted
	}
	if artifact.Input.InviteURLRedacted != "" {
		return artifact.Input.InviteURLRedacted
	}
	return artifact.Input.NormalizedJoinTokenRedacted
}

func redactResolutionInput(providerName string, raw string) string {
	if redacted := genericturn.RedactLink(raw); redacted != "" {
		return redacted
	}

	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return ""
	}
	parsed, err := url.Parse(trimmed)
	if err != nil {
		return "<redacted:provider-link>"
	}
	if parsed.Scheme == "" || parsed.Host == "" {
		return "<redacted:provider-link>"
	}
	parsed.User = nil
	parsed.RawQuery = ""
	parsed.Fragment = ""
	if strings.Contains(parsed.Path, "/call/join/") {
		prefix, _, found := strings.Cut(parsed.Path, "/call/join/")
		if found {
			parsed.Path = prefix + "/call/join/<redacted:invite-token>"
		}
	} else if path := strings.TrimSpace(parsed.Path); path != "" && path != "/" {
		parsed.Path = "/<redacted:provider-link>"
	}
	if parsed.String() == "" {
		return "<redacted:provider-link>"
	}
	return parsed.String()
}

func observeSanitizedLink(link string) string {
	if redacted := genericturn.RedactLink(link); redacted != "" {
		return redacted
	}
	return "<redacted:handoff-link>"
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
