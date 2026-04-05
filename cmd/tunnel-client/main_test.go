package main

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
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
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
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
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
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
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
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
	if !strings.Contains(stderr.String(), "stage=turn_dial") {
		t.Fatalf("stderr missing turn_dial stage: %s", stderr.String())
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
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
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

type fakeClientHost struct {
	startSessionFn   func(context.Context, clientcontrol.StartSessionRequest) (clientcontrol.Session, error)
	waitSessionFn    func(context.Context, string) (clientcontrol.Session, error)
	stopSessionFn    func(string) (clientcontrol.Session, error)
	metricsHandlerFn func(string) (http.Handler, error)
}

func (h fakeClientHost) StartSession(ctx context.Context, req clientcontrol.StartSessionRequest) (clientcontrol.Session, error) {
	return h.startSessionFn(ctx, req)
}

func (h fakeClientHost) WaitSession(ctx context.Context, sessionID string) (clientcontrol.Session, error) {
	return h.waitSessionFn(ctx, sessionID)
}

func (h fakeClientHost) StopSession(sessionID string) (clientcontrol.Session, error) {
	if h.stopSessionFn == nil {
		return clientcontrol.Session{}, nil
	}
	return h.stopSessionFn(sessionID)
}

func (h fakeClientHost) MetricsHandler(sessionID string) (http.Handler, error) {
	if h.metricsHandlerFn == nil {
		return nil, nil
	}
	return h.metricsHandlerFn(sessionID)
}

func TestRunClientInteractiveProviderChallenge(t *testing.T) {
	calledInteractive := false
	previousFactory := newClientHost
	newClientHost = func(_ *slog.Logger, _ io.Reader, _ io.Writer, interactiveProvider bool, sessionID string) clientHost {
		calledInteractive = interactiveProvider
		return fakeClientHost{
			startSessionFn: func(ctx context.Context, req clientcontrol.StartSessionRequest) (clientcontrol.Session, error) {
				return clientcontrol.Session{ID: sessionID}, nil
			},
			waitSessionFn: func(ctx context.Context, sessionID string) (clientcontrol.Session, error) {
				return clientcontrol.Session{
					ID: sessionID,
					Failure: &clientcontrol.FailureInfo{
						Stage:   "provider_resolve",
						Message: "provider challenge completed",
					},
				}, nil
			},
		}
	}
	t.Cleanup(func() {
		newClientHost = previousFactory
	})

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), strings.NewReader("continue\n"), &stdout, &stderr, []string{
		"-provider", "vk",
		"-link", "https://vk.com/call/join/test-token",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-interactive-provider",
	}, newRegistry())
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s stdout=%s", code, stderr.String(), stdout.String())
	}
	if !strings.Contains(stderr.String(), "stage=provider_resolve") {
		t.Fatalf("stderr missing provider_resolve stage: %s", stderr.String())
	}
	if !calledInteractive {
		t.Fatal("expected interactive provider host configuration")
	}
}

func TestRunClientMetricsHappyPathUsesMetricsEndpoint(t *testing.T) {
	var capturedSessionID string
	previousFactory := newClientHost
	newClientHost = func(_ *slog.Logger, _ io.Reader, _ io.Writer, interactiveProvider bool, sessionID string) clientHost {
		capturedSessionID = sessionID
		return fakeClientHost{
			startSessionFn: func(ctx context.Context, req clientcontrol.StartSessionRequest) (clientcontrol.Session, error) {
				return clientcontrol.Session{ID: sessionID}, nil
			},
			waitSessionFn: func(ctx context.Context, sessionID string) (clientcontrol.Session, error) {
				return clientcontrol.Session{ID: sessionID}, context.Canceled
			},
			metricsHandlerFn: func(sessionID string) (http.Handler, error) {
				mux := http.NewServeMux()
				mux.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
					_, _ = w.Write([]byte("ok-metrics\n"))
				})
				return mux, nil
			},
		}
	}
	t.Cleanup(func() {
		newClientHost = previousFactory
	})

	metricsListener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen metrics addr: %v", err)
	}
	metricsAddr := metricsListener.Addr().String()
	metricsListener.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan int, 1)
	go func() {
		var stdout bytes.Buffer
		var stderr bytes.Buffer
		done <- runClient(ctx, bytes.NewBuffer(nil), &stdout, &stderr, []string{
			"-provider", "generic-turn",
			"-link", "generic-turn://user:pass@turn.example.test:3478",
			"-listen", "127.0.0.1:9000",
			"-peer", "127.0.0.1:56000",
			"-metrics-listen", metricsAddr,
		}, newRegistry())
	}()

	deadline := time.After(2 * time.Second)
	for {
		resp, err := http.Get("http://" + metricsAddr + "/metrics")
		if err == nil {
			body, readErr := io.ReadAll(resp.Body)
			resp.Body.Close()
			if readErr != nil {
				t.Fatalf("read metrics response: %v", readErr)
			}
			if !bytes.Contains(body, []byte("ok-metrics")) {
				t.Fatalf("unexpected metrics body: %s", string(body))
			}
			break
		}
		select {
		case <-deadline:
			t.Fatalf("timed out waiting for metrics endpoint: %v", err)
		case <-time.After(20 * time.Millisecond):
		}
	}

	cancel()
	select {
	case code := <-done:
		if code != 0 {
			t.Fatalf("runClient() code = %d", code)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runClient() did not stop after cancellation")
	}
	if capturedSessionID == "" {
		t.Fatal("expected pinned session ID to be passed into host factory")
	}
}

func TestRunClientPreservesNotImplementedExitCode(t *testing.T) {
	previousFactory := newClientHost
	newClientHost = func(_ *slog.Logger, _ io.Reader, _ io.Writer, interactiveProvider bool, sessionID string) clientHost {
		return fakeClientHost{
			startSessionFn: func(ctx context.Context, req clientcontrol.StartSessionRequest) (clientcontrol.Session, error) {
				return clientcontrol.Session{ID: sessionID}, nil
			},
			waitSessionFn: func(ctx context.Context, sessionID string) (clientcontrol.Session, error) {
				return clientcontrol.Session{
					ID: sessionID,
					Failure: &clientcontrol.FailureInfo{
						Stage:          "provider_resolve",
						Message:        provider.ErrNotImplemented.Error(),
						NotImplemented: true,
					},
				}, nil
			},
		}
	}
	t.Cleanup(func() {
		newClientHost = previousFactory
	})

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
		"-provider", "vk",
		"-link", "https://vk.com/call/join/test-token",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
	}, newRegistry())
	if code != 3 {
		t.Fatalf("runClient() code = %d, want 3", code)
	}
	if !strings.Contains(stderr.String(), "stage=provider_resolve") {
		t.Fatalf("stderr missing provider_resolve stage: %s", stderr.String())
	}
}
