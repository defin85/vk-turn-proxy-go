package vpscatalog

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	DefaultCatalogPath       = "/v1/provider-catalog"
	DefaultArtifactIssuePath = "/v1/artifacts:issue"
	DefaultMetricsPath       = "/v1/metrics"
	DefaultAuditPath         = "/v1/audit"
	DefaultAdminPathPrefix   = "/v1/admin/"
)

var (
	ErrUnauthorized       = errors.New("vps catalog request is unauthorized")
	ErrForbidden          = errors.New("vps catalog request is forbidden")
	ErrArtifactNotFound   = errors.New("vps catalog artifact offer was not found")
	ErrOperationIDMissing = errors.New("vps catalog operation_id is required")
	ErrArtifactNotReady   = errors.New("vps catalog artifact offer is not ready")
)

type TokenAuthorizer map[string][]AuthScope

func (a TokenAuthorizer) ScopesForToken(token string) []AuthScope {
	return append([]AuthScope(nil), a[strings.TrimSpace(token)]...)
}

type ServiceOptions struct {
	Snapshot   CatalogSnapshot
	Authorizer TokenAuthorizer
	Now        func() time.Time
}

type Service struct {
	mu         sync.Mutex
	snapshot   CatalogSnapshot
	authorizer TokenAuthorizer
	now        func() time.Time
	issues     map[string]ArtifactIssueResponse
	audit      []AuditRecord
	metrics    MetricsSnapshot
}

func NewService(opts ServiceOptions) *Service {
	now := opts.Now
	if now == nil {
		now = time.Now
	}
	return &Service{
		snapshot:   CloneSnapshot(opts.Snapshot),
		authorizer: cloneAuthorizer(opts.Authorizer),
		now:        now,
		issues:     make(map[string]ArtifactIssueResponse),
		metrics: MetricsSnapshot{
			CatalogReads:     make(map[string]uint64),
			ArtifactIssues:   make(map[string]uint64),
			Authorization:    make(map[string]uint64),
			EvidenceOutcomes: make(map[string]uint64),
		},
	}
}

func (s *Service) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc(DefaultCatalogPath, s.handleCatalog)
	mux.HandleFunc(DefaultArtifactIssuePath, s.handleArtifactIssue)
	mux.HandleFunc(DefaultMetricsPath, s.handleMetrics)
	mux.HandleFunc(DefaultAuditPath, s.handleAudit)
	mux.HandleFunc(DefaultAdminPathPrefix, s.handleAdmin)
	return mux
}

func (s *Service) AuditRecords() []AuditRecord {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]AuditRecord(nil), s.audit...)
}

func (s *Service) MetricsSnapshot() MetricsSnapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	return cloneMetricsSnapshot(s.metrics)
}

func (s *Service) handleCatalog(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w, r.Method)
		return
	}
	if !s.authorize(r, AuthScopeCatalogRead) {
		s.recordAudit("catalog_read", AuthScopeCatalogRead, "denied", "", "", "", "", "authorization_failed", auditActor(r, AuditContext{}))
		writeError(w, http.StatusForbidden, "catalog_forbidden", ErrForbidden)
		return
	}
	s.mu.Lock()
	s.metrics.CatalogReads["status=ok"]++
	snapshot := CloneSnapshot(s.snapshot)
	s.mu.Unlock()
	s.recordAudit("catalog_read", AuthScopeCatalogRead, "ok", "", "", "", "", "", auditActor(r, AuditContext{}))
	writeJSON(w, http.StatusOK, snapshot)
}

func (s *Service) handleArtifactIssue(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeMethodNotAllowed(w, r.Method)
		return
	}
	var req ArtifactIssueRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json", err)
		return
	}
	req.SourceID = strings.TrimSpace(req.SourceID)
	req.OfferID = strings.TrimSpace(req.OfferID)
	req.OperationID = strings.TrimSpace(req.OperationID)
	if req.OperationID == "" {
		s.recordAudit("artifact_issue", AuthScopeArtifactIssue, "denied", "", "", req.SourceID, req.OfferID, "operation_id_missing", auditActor(r, req.Audit))
		writeError(w, http.StatusBadRequest, "operation_id_required", ErrOperationIDMissing)
		return
	}
	if !s.authorize(r, AuthScopeArtifactIssue) {
		s.recordAudit("artifact_issue", AuthScopeArtifactIssue, "denied", "", "", req.SourceID, req.OfferID, "authorization_failed", auditActor(r, req.Audit))
		writeError(w, http.StatusForbidden, "artifact_issue_forbidden", ErrForbidden)
		return
	}

	s.mu.Lock()
	if existing, ok := s.issues[req.OperationID]; ok {
		s.metrics.ArtifactIssues["status=idempotent_retry"]++
		s.mu.Unlock()
		s.recordAudit("artifact_issue", AuthScopeArtifactIssue, "idempotent_retry", "", existing.Artifact.Family, req.SourceID, req.OfferID, "", auditActor(r, req.Audit))
		writeJSON(w, http.StatusOK, existing)
		return
	}

	source, offer, ok := findOffer(s.snapshot, req.SourceID, req.OfferID)
	if !ok {
		s.metrics.ArtifactIssues["status=not_found"]++
		s.mu.Unlock()
		s.recordAudit("artifact_issue", AuthScopeArtifactIssue, "not_found", "", "", req.SourceID, req.OfferID, "not_found", auditActor(r, req.Audit))
		writeError(w, http.StatusNotFound, "artifact_offer_not_found", ErrArtifactNotFound)
		return
	}
	now := s.now().UTC()
	readiness := ValidateOfferReadiness(source, offer, now)
	if readiness.Status != ValidationStatusValid {
		s.metrics.ArtifactIssues["status="+string(readiness.Status)]++
		s.metrics.EvidenceOutcomes["status="+string(readiness.Status)]++
		s.mu.Unlock()
		s.recordAudit(
			"artifact_issue",
			AuthScopeArtifactIssue,
			string(readiness.Status),
			source.SourceFamily,
			offer.Family,
			req.SourceID,
			req.OfferID,
			readiness.Reason,
			auditActor(r, req.Audit),
		)
		writeError(w, http.StatusConflict, "artifact_offer_not_ready", fmt.Errorf("%w: %s", ErrArtifactNotReady, readiness.Message))
		return
	}
	response := s.issueResponseLocked(req, source, offer, now)
	s.issues[req.OperationID] = response
	s.metrics.ArtifactIssues["status=ok"]++
	s.metrics.EvidenceOutcomes["status=valid"]++
	s.mu.Unlock()

	s.recordAudit("artifact_issue", AuthScopeArtifactIssue, "ok", source.SourceFamily, offer.Family, req.SourceID, req.OfferID, "", auditActor(r, req.Audit))
	writeJSON(w, http.StatusOK, response)
}

func (s *Service) handleAdmin(w http.ResponseWriter, r *http.Request) {
	if !s.authorize(r, AuthScopeAdminMutation) {
		s.recordAudit("admin_mutation", AuthScopeAdminMutation, "denied", "", "", "", "", "authorization_failed", auditActor(r, AuditContext{}))
		writeError(w, http.StatusForbidden, "admin_forbidden", ErrForbidden)
		return
	}
	writeError(w, http.StatusNotImplemented, "admin_not_implemented", errors.New("catalog admin mutation API is not implemented by this bounded service"))
}

func (s *Service) handleMetrics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w, r.Method)
		return
	}
	if !s.authorize(r, AuthScopeAdminMutation) {
		s.recordAudit("metrics_read", AuthScopeAdminMutation, "denied", "", "", "", "", "authorization_failed", auditActor(r, AuditContext{}))
		writeError(w, http.StatusForbidden, "metrics_forbidden", ErrForbidden)
		return
	}
	s.recordAudit("metrics_read", AuthScopeAdminMutation, "ok", "", "", "", "", "", auditActor(r, AuditContext{}))
	writeJSON(w, http.StatusOK, s.MetricsSnapshot())
}

func (s *Service) handleAudit(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeMethodNotAllowed(w, r.Method)
		return
	}
	if !s.authorize(r, AuthScopeAdminMutation) {
		s.recordAudit("audit_read", AuthScopeAdminMutation, "denied", "", "", "", "", "authorization_failed", auditActor(r, AuditContext{}))
		writeError(w, http.StatusForbidden, "audit_forbidden", ErrForbidden)
		return
	}
	s.recordAudit("audit_read", AuthScopeAdminMutation, "ok", "", "", "", "", "", auditActor(r, AuditContext{}))
	writeJSON(w, http.StatusOK, s.AuditRecords())
}

func (s *Service) authorize(r *http.Request, scope AuthScope) bool {
	token := bearerToken(r.Header.Get("Authorization"))
	if token == "" {
		s.countAuthorization("missing")
		return false
	}
	scopes := s.authorizer.ScopesForToken(token)
	for _, candidate := range scopes {
		if candidate == scope {
			s.countAuthorization("ok")
			return true
		}
	}
	s.countAuthorization("denied")
	return false
}

func (s *Service) countAuthorization(status string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.metrics.Authorization == nil {
		s.metrics.Authorization = make(map[string]uint64)
	}
	s.metrics.Authorization["status="+status]++
}

func (s *Service) issueResponseLocked(
	req ArtifactIssueRequest,
	source ProviderSource,
	offer ArtifactOffer,
	now time.Time,
) ArtifactIssueResponse {
	ttl := time.Duration(req.TTLSeconds) * time.Second
	if ttl <= 0 || (offer.MaxTTLSeconds > 0 && ttl > time.Duration(offer.MaxTTLSeconds)*time.Second) {
		ttl = time.Duration(offer.MaxTTLSeconds) * time.Second
	}
	if ttl <= 0 {
		ttl = time.Minute
	}
	expiresAt := now.Add(ttl).UTC()
	artifactID := artifactIssueID(s.snapshot, req)
	redaction := offer.Redaction
	if redaction == (RedactionPolicy{}) {
		redaction = DefaultRedactionPolicy()
	}
	provenance := offer.Provenance
	provenance.EndpointID = firstNonEmpty(provenance.EndpointID, s.snapshot.EndpointID)
	provenance.Issuer = firstNonEmpty(provenance.Issuer, s.snapshot.Issuer)
	provenance.Audience = firstNonEmpty(provenance.Audience, s.snapshot.Audience)
	if provenance.Generation == 0 {
		provenance.Generation = s.snapshot.Generation
	}
	provenance.SourceID = firstNonEmpty(provenance.SourceID, source.ID)
	provenance.OfferID = firstNonEmpty(provenance.OfferID, offer.ID)
	response := ArtifactIssueResponse{
		OperationID: req.OperationID,
		IssuedAt:    now,
		ExpiresAt:   expiresAt,
		Source: SourceReference{
			EndpointID: s.snapshot.EndpointID,
			Issuer:     s.snapshot.Issuer,
			Audience:   s.snapshot.Audience,
			Generation: s.snapshot.Generation,
			ProviderID: source.ProviderID,
			SourceID:   source.ID,
		},
		Artifact: ArtifactReference{
			ID:                     artifactID,
			SourceID:               source.ID,
			OfferID:                offer.ID,
			Family:                 offer.Family,
			AccessMethods:          append([]string(nil), offer.AccessMethods...),
			Actions:                append([]string(nil), offer.Actions...),
			RemoteEndpointFamily:   offer.RemoteEndpointFamily,
			RemoteEndpointRole:     offer.RemoteEndpointRole,
			CompatibleProfileKinds: append([]string(nil), offer.CompatibleProfileKinds...),
			Health:                 offer.Health,
			Evidence:               append([]Evidence(nil), offer.Evidence...),
			ExpiresAt:              expiresAt,
		},
		Redaction:  redaction,
		Provenance: provenance,
	}
	if req.ExportSecret {
		response.Export = &ArtifactExport{
			Kind:            "redacted_reference",
			PayloadRedacted: true,
		}
	}
	return response
}

func (s *Service) recordAudit(
	action string,
	scope AuthScope,
	status string,
	sourceFamily string,
	artifactFamily string,
	sourceID string,
	offerID string,
	reason string,
	actor string,
) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.audit = append(s.audit, AuditRecord{
		Timestamp:      s.now().UTC(),
		Action:         action,
		Scope:          scope,
		Status:         status,
		SourceFamily:   sourceFamily,
		ArtifactFamily: artifactFamily,
		SourceID:       sourceID,
		OfferID:        offerID,
		Reason:         reason,
		Actor:          actor,
	})
}

func findOffer(snapshot CatalogSnapshot, sourceID string, offerID string) (ProviderSource, ArtifactOffer, bool) {
	for _, source := range snapshot.Sources {
		if source.ID != sourceID {
			continue
		}
		for _, offer := range source.ArtifactOffers {
			if offer.ID == offerID {
				return CloneSource(source), CloneOffer(offer), true
			}
		}
	}
	return ProviderSource{}, ArtifactOffer{}, false
}

func artifactIssueID(snapshot CatalogSnapshot, req ArtifactIssueRequest) string {
	sum := sha256.Sum256([]byte(strings.Join([]string{
		snapshot.EndpointID,
		snapshot.Issuer,
		fmt.Sprint(snapshot.Generation),
		req.SourceID,
		req.OfferID,
		req.OperationID,
	}, "|")))
	return "vps-artifact-" + hex.EncodeToString(sum[:8])
}

func bearerToken(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	token, ok := strings.CutPrefix(value, "Bearer ")
	if !ok {
		return ""
	}
	return strings.TrimSpace(token)
}

func auditActor(r *http.Request, audit AuditContext) string {
	if audit.Actor != "" {
		return strings.TrimSpace(audit.Actor)
	}
	return strings.TrimSpace(r.Header.Get("X-Actor"))
}

func cloneAuthorizer(authorizer TokenAuthorizer) TokenAuthorizer {
	out := make(TokenAuthorizer, len(authorizer))
	for token, scopes := range authorizer {
		out[token] = append([]AuthScope(nil), scopes...)
	}
	return out
}

func cloneMetricsSnapshot(snapshot MetricsSnapshot) MetricsSnapshot {
	return MetricsSnapshot{
		CatalogReads:     cloneUintMap(snapshot.CatalogReads),
		ArtifactIssues:   cloneUintMap(snapshot.ArtifactIssues),
		Authorization:    cloneUintMap(snapshot.Authorization),
		EvidenceOutcomes: cloneUintMap(snapshot.EvidenceOutcomes),
	}
}

func cloneUintMap(values map[string]uint64) map[string]uint64 {
	if len(values) == 0 {
		return nil
	}
	out := make(map[string]uint64, len(values))
	for key, value := range values {
		out[key] = value
	}
	return out
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, code string, err error) {
	message := ""
	if err != nil {
		message = err.Error()
	}
	writeJSON(w, status, map[string]string{
		"code":    code,
		"message": message,
	})
}

func writeMethodNotAllowed(w http.ResponseWriter, method string) {
	w.Header().Set("Allow", "GET, POST")
	writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", fmt.Errorf("method %s is not allowed", method))
}
