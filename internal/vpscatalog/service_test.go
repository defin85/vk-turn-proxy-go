package vpscatalog

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestServiceCatalogReadAndScopedIssueAuthorization(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	service := NewService(ServiceOptions{
		Snapshot: AttachIntegrity(testSnapshot(now), "test"),
		Now:      func() time.Time { return now },
		Authorizer: TokenAuthorizer{
			"read-token":  {AuthScopeCatalogRead},
			"issue-token": {AuthScopeCatalogRead, AuthScopeArtifactIssue},
		},
	})
	server := httptest.NewServer(service.Handler())
	t.Cleanup(server.Close)

	req, _ := http.NewRequest(http.MethodGet, server.URL+DefaultCatalogPath, nil)
	req.Header.Set("Authorization", "Bearer read-token")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET catalog error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET catalog status = %d, want 200", resp.StatusCode)
	}
	var snapshot CatalogSnapshot
	if err := json.NewDecoder(resp.Body).Decode(&snapshot); err != nil {
		t.Fatalf("decode snapshot: %v", err)
	}
	if snapshot.Sources[0].ArtifactOffers[0].Redaction.OrdinaryReads != RedactionModeReferenceOnly {
		t.Fatalf("redaction = %+v, want reference-only ordinary reads", snapshot.Sources[0].ArtifactOffers[0].Redaction)
	}

	body, _ := json.Marshal(ArtifactIssueRequest{
		SourceID:    "managed-turn",
		OfferID:     "turn-handoff",
		OperationID: "op-denied",
	})
	req, _ = http.NewRequest(http.MethodPost, server.URL+DefaultArtifactIssuePath, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer read-token")
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST issue with read token error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("POST issue with read token status = %d, want 403", resp.StatusCode)
	}

	audit := service.AuditRecords()
	if len(audit) == 0 {
		t.Fatal("audit records empty, want denied action recorded")
	}
	if audit[len(audit)-1].Status != "denied" {
		t.Fatalf("last audit status = %q, want denied", audit[len(audit)-1].Status)
	}
}

func TestServiceArtifactIssueIsIdempotentAndRejectsStaleEvidence(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	service := NewService(ServiceOptions{
		Snapshot: AttachIntegrity(testSnapshot(now), "test"),
		Now:      func() time.Time { return now },
		Authorizer: TokenAuthorizer{
			"issue-token": {AuthScopeArtifactIssue},
		},
	})
	server := httptest.NewServer(service.Handler())
	t.Cleanup(server.Close)

	first := issueArtifact(t, server.URL, "issue-token", ArtifactIssueRequest{
		SourceID:    "managed-turn",
		OfferID:     "turn-handoff",
		OperationID: "op-1",
		TTLSeconds:  30,
	})
	second := issueArtifact(t, server.URL, "issue-token", ArtifactIssueRequest{
		SourceID:    "managed-turn",
		OfferID:     "turn-handoff",
		OperationID: "op-1",
		TTLSeconds:  30,
	})
	if first.Artifact.ID != second.Artifact.ID {
		t.Fatalf("idempotent artifact id changed: %q vs %q", first.Artifact.ID, second.Artifact.ID)
	}
	metrics := service.MetricsSnapshot()
	if metrics.ArtifactIssues["status=idempotent_retry"] != 1 {
		t.Fatalf("idempotent retry metric = %d, want 1", metrics.ArtifactIssues["status=idempotent_retry"])
	}

	staleSnapshot := testSnapshot(now)
	staleSnapshot.Sources[0].ArtifactOffers[0].Evidence[0].Status = EvidenceStatusStale
	staleService := NewService(ServiceOptions{
		Snapshot: AttachIntegrity(staleSnapshot, "test"),
		Now:      func() time.Time { return now },
		Authorizer: TokenAuthorizer{
			"issue-token": {AuthScopeArtifactIssue},
		},
	})
	staleServer := httptest.NewServer(staleService.Handler())
	t.Cleanup(staleServer.Close)

	body, _ := json.Marshal(ArtifactIssueRequest{
		SourceID:    "managed-turn",
		OfferID:     "turn-handoff",
		OperationID: "op-stale",
	})
	req, _ := http.NewRequest(http.MethodPost, staleServer.URL+DefaultArtifactIssuePath, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer issue-token")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST stale issue error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusConflict {
		t.Fatalf("POST stale issue status = %d, want 409", resp.StatusCode)
	}
}

func TestServiceAdminMetricsAndAuditRequireAdminScope(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	service := NewService(ServiceOptions{
		Snapshot: AttachIntegrity(testSnapshot(now), "test"),
		Now:      func() time.Time { return now },
		Authorizer: TokenAuthorizer{
			"issue-token": {AuthScopeArtifactIssue},
			"admin-token": {AuthScopeAdminMutation},
		},
	})
	server := httptest.NewServer(service.Handler())
	t.Cleanup(server.Close)

	req, _ := http.NewRequest(http.MethodGet, server.URL+DefaultMetricsPath, nil)
	req.Header.Set("Authorization", "Bearer issue-token")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET metrics with issue token error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("GET metrics with issue token status = %d, want 403", resp.StatusCode)
	}

	req, _ = http.NewRequest(http.MethodGet, server.URL+DefaultAuditPath, nil)
	req.Header.Set("Authorization", "Bearer admin-token")
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET audit with admin token error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET audit with admin token status = %d, want 200", resp.StatusCode)
	}
	var audit []AuditRecord
	if err := json.NewDecoder(resp.Body).Decode(&audit); err != nil {
		t.Fatalf("decode audit: %v", err)
	}
	if len(audit) == 0 || audit[len(audit)-1].Action != "audit_read" {
		t.Fatalf("audit records = %+v, want audit_read trail", audit)
	}
}

func issueArtifact(t *testing.T, baseURL string, token string, reqBody ArtifactIssueRequest) ArtifactIssueResponse {
	t.Helper()
	body, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest(http.MethodPost, baseURL+DefaultArtifactIssuePath, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST issue error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST issue status = %d, want 200", resp.StatusCode)
	}
	var response ArtifactIssueResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		t.Fatalf("decode issue response: %v", err)
	}
	return response
}
