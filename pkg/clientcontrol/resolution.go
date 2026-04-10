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

type managedResolution struct {
	snapshot   Resolution
	secret     provider.Resolution
	cancel     context.CancelFunc
	done       chan struct{}
	input      StartResolutionRequest
	events     []Event
	challenges []Challenge
}

func (h *Host) StartResolution(ctx context.Context, req StartResolutionRequest) (Resolution, error) {
	normalized, err := normalizeStartResolutionRequest(req)
	if err != nil {
		return Resolution{}, err
	}
	if _, err := h.registry.Get(normalized.Provider); err != nil {
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
			LinkRedacted:        redactResolutionInput(normalized.Provider, normalized.Link),
			InteractiveProvider: normalized.InteractiveProvider,
		},
		State:     ResolutionStateStarting,
		Export:    ResolutionExportStatus{Supported: false},
		StartedAt: startedAt,
		UpdatedAt: startedAt,
	}
	managed := &managedResolution{
		snapshot: snapshot,
		cancel:   cancel,
		done:     make(chan struct{}),
		input:    normalized,
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

	resolution, err := adapter.Resolve(runCtx, req.Link)
	if err != nil {
		h.finishResolutionFailure(resolutionID, err)
		return
	}
	h.finishResolutionSuccess(resolutionID, resolution)
}

func (h *Host) finishResolutionSuccess(resolutionID string, resolved provider.Resolution) {
	if strings.TrimSpace(resolved.Credentials.Username) == "" ||
		strings.TrimSpace(resolved.Credentials.Password) == "" ||
		strings.TrimSpace(resolved.Credentials.Address) == "" {
		h.finishResolutionFailure(resolutionID, errors.New("provider resolution returned incomplete TURN credentials"))
		return
	}

	now := h.now().UTC()
	h.mu.Lock()
	managed, ok := h.resolutions[resolutionID]
	if !ok {
		h.mu.Unlock()
		return
	}
	managed.secret = resolved
	managed.snapshot.Provider = firstNonEmpty(strings.TrimSpace(resolved.Metadata["provider"]), managed.snapshot.Provider)
	managed.snapshot.ResolutionMethod = strings.TrimSpace(resolved.Metadata["resolution_method"])
	managed.snapshot.Input.LinkRedacted = firstNonEmpty(redactedLinkFromArtifact(resolved.Artifact), managed.snapshot.Input.LinkRedacted)
	managed.snapshot.Credentials = redactedResolutionCredentials(resolved)
	managed.snapshot.Export = resolutionExportStatus(resolved, now)
	managed.snapshot.State = ResolutionStateResolved
	managed.snapshot.ActiveChallengeID = ""
	managed.snapshot.UpdatedAt = now
	managed.snapshot.ResolvedAt = &now
	if managed.snapshot.Export.ExpiresAt != nil && !managed.snapshot.Export.ExpiresAt.After(now) {
		managed.snapshot.State = ResolutionStateExpired
		managed.snapshot.Export.Supported = false
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
	h.mu.Unlock()

	h.publishEvent(event)
	close(done)
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
	message := err.Error()
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
	}
	h.mu.Unlock()

	if !alreadyClosed {
		h.publishEvent(event)
		close(done)
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

	record := Challenge{
		ID:           b.host.newID(),
		ResolutionID: b.resolutionID,
		Provider:     challenge.ProviderName(),
		Stage:        challenge.StageName(),
		Kind:         challenge.Kind(),
		Prompt:       providerprompt.ContinuationPrompt(challenge),
		OpenURL:      providerprompt.ContinuationOpenURL(challenge),
		Status:       ChallengeStatusPending,
		CreatedAt:    b.host.now().UTC(),
		UpdatedAt:    b.host.now().UTC(),
	}
	b.host.recordResolutionChallenge(b.resolutionID, record)

	action, err := b.host.waitChallengeAction(ctx, record.ID)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return fmt.Errorf("interactive provider challenge aborted: %w", err)
	}
	if action == challengeActionCancel {
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

	continuation, err := b.host.startContinuation(ctx, challenge)
	if err != nil {
		return nil, err
	}
	defer func() {
		_ = continuation.Close()
	}()

	record := Challenge{
		ID:           b.host.newID(),
		ResolutionID: b.resolutionID,
		Provider:     challenge.ProviderName(),
		Stage:        challenge.StageName(),
		Kind:         challenge.Kind(),
		Prompt:       providerprompt.ContinuationPrompt(challenge),
		OpenURL:      providerprompt.ContinuationOpenURL(challenge),
		Status:       ChallengeStatusPending,
		CreatedAt:    b.host.now().UTC(),
		UpdatedAt:    b.host.now().UTC(),
	}
	b.host.recordResolutionChallenge(b.resolutionID, record)

	action, err := b.host.waitChallengeAction(ctx, record.ID)
	if err != nil {
		b.host.completeChallenge(record.ID, ChallengeStatusFailed, err.Error())
		return nil, fmt.Errorf("interactive provider challenge aborted: %w", err)
	}
	if action == challengeActionCancel {
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

func normalizeStartResolutionRequest(req StartResolutionRequest) (StartResolutionRequest, error) {
	req.Provider = strings.TrimSpace(req.Provider)
	req.Link = strings.TrimSpace(req.Link)
	if req.Provider == "" {
		return StartResolutionRequest{}, errors.New("provider is required")
	}
	if req.Link == "" {
		return StartResolutionRequest{}, errors.New("link is required")
	}
	return req, nil
}

func buildMaterializedProfileSpec(credentials provider.Credentials, defaults RuntimeDefaults) (ProfileSpec, error) {
	spec := ProfileSpec{
		Provider:      "generic-turn",
		Link:          genericturn.FormatLink(credentials),
		ListenAddr:    defaults.ListenAddr,
		PeerAddr:      defaults.PeerAddr,
		Ingress:       defaults.Ingress,
		Connections:   defaults.Connections,
		BindInterface: defaults.BindInterface,
		Mode:          defaults.Mode,
		UseDTLS:       defaults.UseDTLS,
		LogLevel:      defaults.LogLevel,
	}
	return normalizeProfileSpec(spec)
}

func failureInfoFromResolutionError(err error) *FailureInfo {
	info := &FailureInfo{
		Message:        err.Error(),
		NotImplemented: errors.Is(err, provider.ErrNotImplemented),
	}
	var artifactErr *provider.ArtifactError
	if errors.As(err, &artifactErr) && artifactErr.ProbeArtifact != nil && artifactErr.ProbeArtifact.Outcome.ProviderError != nil {
		info.Stage = artifactErr.ProbeArtifact.Outcome.ProviderError.Stage
	}
	return info
}

func resolutionSnapshotEvent(snapshot Resolution, eventType EventType, message string) Event {
	return Event{
		Timestamp:       snapshot.UpdatedAt,
		ResolutionID:    snapshot.ID,
		Type:            eventType,
		ResolutionState: snapshot.State,
		Message:         message,
	}
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
	parsed.RawQuery = ""
	parsed.Fragment = ""
	if strings.Contains(parsed.Path, "/call/join/") {
		prefix, _, found := strings.Cut(parsed.Path, "/call/join/")
		if found {
			parsed.Path = prefix + "/call/join/<redacted:invite-token>"
		}
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
