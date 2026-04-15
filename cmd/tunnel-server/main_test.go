package main

import (
	"bytes"
	"context"
	"net"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
)

func TestRunServerEmitsStructuredPolicyValidateFailure(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	code := runServer(context.Background(), &stdout, &stderr, []string{
		"-listen", "127.0.0.1:56000",
		"-connect", "",
	})
	if code != 2 {
		t.Fatalf("runServer() code = %d, stderr=%s stdout=%s", code, stderr.String(), stdout.String())
	}
	if !strings.Contains(stderr.String(), "init server:") {
		t.Fatalf("stderr missing init failure: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "event=runtime_failure") || !strings.Contains(stdout.String(), "stage=policy_validate") {
		t.Fatalf("stdout missing structured policy_validate event: %s", stdout.String())
	}
}

func TestRunServerEmitsStructuredMetricsListenFailure(t *testing.T) {
	metricsListener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen metrics addr: %v", err)
	}
	defer metricsListener.Close()

	var stdout bytes.Buffer
	var stderr bytes.Buffer

	code := runServer(context.Background(), &stdout, &stderr, []string{
		"-listen", "127.0.0.1:0",
		"-connect", "127.0.0.1:1",
		"-metrics-listen", metricsListener.Addr().String(),
	})
	if code != 1 {
		t.Fatalf("runServer() code = %d, stderr=%s stdout=%s", code, stderr.String(), stdout.String())
	}
	if !strings.Contains(stderr.String(), "server metrics failed:") {
		t.Fatalf("stderr missing metrics failure: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "event=runtime_failure") || !strings.Contains(stdout.String(), "stage=metrics_listen") {
		t.Fatalf("stdout missing structured metrics_listen event: %s", stdout.String())
	}
}

func TestParseServerFlagsParsesPlainPeerMode(t *testing.T) {
	cfg, _, _, err := parseServerFlags(&bytes.Buffer{}, []string{
		"-listen", "127.0.0.1:0",
		"-connect", "127.0.0.1:51820",
		"-peer-mode", "plain",
	})
	if err != nil {
		t.Fatalf("parseServerFlags() error = %v", err)
	}
	if cfg.PeerMode != config.ServerPeerModePlain {
		t.Fatalf("peer mode = %q, want %q", cfg.PeerMode, config.ServerPeerModePlain)
	}
}
