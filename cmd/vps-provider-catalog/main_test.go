package main

import (
	"bytes"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/vpscatalog"
)

func TestParseFlagsRequiresScopedTokens(t *testing.T) {
	var stderr bytes.Buffer
	if _, err := parseFlags(&stderr, nil); err == nil {
		t.Fatal("parseFlags() error = nil, want missing token error")
	}

	cfg, err := parseFlags(&stderr, []string{
		"-read-token", "same-token",
		"-issue-token", "same-token",
		"-admin-token", "admin-token",
		"-issuer", "issuer",
		"-audience", "audience",
		"-endpoint-id", "endpoint",
	})
	if err != nil {
		t.Fatalf("parseFlags() error = %v", err)
	}
	authorizer := authorizerFromConfig(cfg)
	scopes := authorizer.ScopesForToken("same-token")
	if len(scopes) != 2 {
		t.Fatalf("shared token scopes = %+v, want read and issue scopes", scopes)
	}
}

func TestSampleSnapshotValidatesAsSignedCatalog(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	cfg := config{
		Issuer:     "issuer",
		Audience:   "audience",
		EndpointID: "endpoint",
	}
	snapshot := vpscatalog.AttachIntegrity(sampleSnapshot(now, cfg), "test")
	result, err := vpscatalog.ValidateSnapshot(snapshot, vpscatalog.ValidationOptions{
		Now:                now,
		ExpectedIssuer:     "issuer",
		ExpectedAudience:   "audience",
		ExpectedEndpointID: "endpoint",
		RequireSigned:      true,
	})
	if err != nil {
		t.Fatalf("ValidateSnapshot() error = %v", err)
	}
	if result.Status != vpscatalog.ValidationStatusValid {
		t.Fatalf("validation status = %q, want valid", result.Status)
	}
}
