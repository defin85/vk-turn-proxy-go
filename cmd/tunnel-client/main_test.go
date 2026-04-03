package main

import (
	"bytes"
	"context"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestNewRegistryIncludesGenericTurn(t *testing.T) {
	registry := newRegistry()

	for _, name := range []string{"generic-turn", "vk"} {
		adapter, err := registry.Get(name)
		if err != nil {
			t.Fatalf("registry.Get(%q) error = %v", name, err)
		}
		if adapter.Name() != name {
			t.Fatalf("unexpected adapter name %q for %q", adapter.Name(), name)
		}
	}
}

func TestRunClientRejectsInvalidConfig(t *testing.T) {
	var stderr bytes.Buffer
	code := runClient(context.Background(), &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "",
		"-peer", "127.0.0.1:56000",
	}, newRegistry())
	if code != 2 {
		t.Fatalf("runClient() code = %d, stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stderr.String(), "invalid client config:") {
		t.Fatalf("stderr missing invalid config message: %s", stderr.String())
	}
}

func TestRunClientReportsStageAwareFailure(t *testing.T) {
	var stderr bytes.Buffer
	code := runClient(context.Background(), &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-dtls=false",
	}, provider.NewRegistry())
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stderr.String(), "stage=policy_validate") {
		t.Fatalf("stderr missing stage: %s", stderr.String())
	}
}
