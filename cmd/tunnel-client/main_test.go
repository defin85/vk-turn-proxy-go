package main

import (
	"bytes"
	"context"
	"net"
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
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), &stdout, &stderr, []string{
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
	if !strings.Contains(stdout.String(), "event=runtime_failure") || !strings.Contains(stdout.String(), "stage=policy_validate") {
		t.Fatalf("stdout missing structured policy_validate event: %s", stdout.String())
	}
}

func TestRunClientReportsStageAwareFailure(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), &stdout, &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-bind-interface", "eth0",
	}, provider.NewRegistry())
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stderr.String(), "stage=policy_validate") {
		t.Fatalf("stderr missing stage: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "event=runtime_failure") || !strings.Contains(stdout.String(), "stage=policy_validate") {
		t.Fatalf("stdout missing structured policy_validate event: %s", stdout.String())
	}
}

func TestRunClientAllowsSupervisedPolicyToReachRuntime(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), &stdout, &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-connections", "2",
		"-mode", "tcp",
		"-dtls=false",
		"-bind-interface", "127.0.0.1",
	}, provider.NewRegistry())
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stderr.String(), "stage=provider_resolve") {
		t.Fatalf("stderr missing provider_resolve stage: %s", stderr.String())
	}
}

func TestRunClientEmitsStructuredMetricsListenFailure(t *testing.T) {
	metricsListener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen metrics addr: %v", err)
	}
	defer metricsListener.Close()

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), &stdout, &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-metrics-listen", metricsListener.Addr().String(),
	}, newRegistry())
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s stdout=%s", code, stderr.String(), stdout.String())
	}
	if !strings.Contains(stderr.String(), "client metrics failed:") {
		t.Fatalf("stderr missing metrics failure: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "event=runtime_failure") || !strings.Contains(stdout.String(), "stage=metrics_listen") {
		t.Fatalf("stdout missing structured metrics_listen event: %s", stdout.String())
	}
}
