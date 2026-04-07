package clientcontrol

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

func TestHandlerHostAndNegotiate(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(BuildIdentity{
			Product:     "vk-turn-proxy-go",
			Version:     "0.1.0",
			BuildNumber: "1",
			Revision:    "deadbeefcafe",
			Dirty:       true,
			BuiltAt:     "2026-04-07T12:00:00Z",
			Role:        "clientd",
			Target:      "linux/amd64",
		}),
	)
	handler := Handler(host)

	req := httptest.NewRequest(http.MethodGet, "/v1/host", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/host code = %d", rec.Code)
	}
	var info HostInfo
	if err := json.Unmarshal(rec.Body.Bytes(), &info); err != nil {
		t.Fatalf("decode host info: %v", err)
	}
	if info.Version != ContractVersion {
		t.Fatalf("version = %q, want %q", info.Version, ContractVersion)
	}
	if info.ContractVersion != ContractVersion {
		t.Fatalf("contract_version = %q, want %q", info.ContractVersion, ContractVersion)
	}
	if info.Build.Version != "0.1.0" {
		t.Fatalf("build version = %q, want 0.1.0", info.Build.Version)
	}

	body, _ := json.Marshal(NegotiateRequest{
		SupportedVersions: []string{ContractVersion},
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/negotiate", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /v1/negotiate code = %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestHandlerSessionDiagnosticsAndMetrics(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(BuildIdentity{
			Product:     "vk-turn-proxy-go",
			Version:     "0.1.0",
			BuildNumber: "1",
			Revision:    "deadbeefcafe",
			Dirty:       true,
			BuiltAt:     "2026-04-07T12:00:00Z",
			Role:        "clientd",
			Target:      "linux/amd64",
		}),
		WithSessionIDSource(func() string { return "session-http" }),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "generic-turn",
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
				}, nil
			},
		})),
		withRunnerFactory(func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{run: func(ctx context.Context) error {
				if cfg.Hooks.OnReady != nil {
					cfg.Hooks.OnReady()
				}
				if cfg.Hooks.OnTraffic != nil {
					cfg.Hooks.OnTraffic(transport.TrafficDirectionLocalToRelay, 5)
				}
				<-ctx.Done()
				return nil
			}}
		}),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(StartSessionRequest{
		Spec: &ProfileSpec{
			Provider:    "generic-turn",
			Link:        "generic-turn://user:pass@turn.example.test:3478",
			ListenAddr:  reserveUDPAddr(t),
			PeerAddr:    "127.0.0.1:56000",
			Connections: 1,
			Mode:        TransportModeAuto,
			UseDTLS:     boolRef(true),
		},
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/sessions", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("POST /v1/sessions code = %d body=%s", rec.Code, rec.Body.String())
	}

	var sessionState Session
	if err := json.Unmarshal(rec.Body.Bytes(), &sessionState); err != nil {
		t.Fatalf("decode session response: %v", err)
	}

	waitForSessionState(t, host, sessionState.ID, SessionStateReady)

	req = httptest.NewRequest(http.MethodGet, "/v1/sessions/"+sessionState.ID+"/diagnostics", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET diagnostics code = %d body=%s", rec.Code, rec.Body.String())
	}
	var diagnostics Diagnostics
	if err := json.Unmarshal(rec.Body.Bytes(), &diagnostics); err != nil {
		t.Fatalf("decode diagnostics: %v", err)
	}
	if diagnostics.Session.ID != sessionState.ID {
		t.Fatalf("diagnostics session_id = %q, want %q", diagnostics.Session.ID, sessionState.ID)
	}
	if diagnostics.ContractVersion != ContractVersion {
		t.Fatalf("diagnostics contract_version = %q, want %q", diagnostics.ContractVersion, ContractVersion)
	}
	if diagnostics.HostBuild.Version != "0.1.0" {
		t.Fatalf("diagnostics host build version = %q, want 0.1.0", diagnostics.HostBuild.Version)
	}

	metricsHandler, err := host.MetricsHandler(sessionState.ID)
	if err != nil {
		t.Fatalf("MetricsHandler() error = %v", err)
	}
	req = httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec = httptest.NewRecorder()
	metricsHandler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /metrics code = %d body=%s", rec.Code, rec.Body.String())
	}
	if !bytes.Contains(rec.Body.Bytes(), []byte("vk_turn_proxy_runtime_session_starts_total")) {
		t.Fatalf("metrics output missing session starts: %s", rec.Body.String())
	}

	if _, err := host.StopSession(sessionState.ID); err != nil {
		t.Fatalf("StopSession() error = %v", err)
	}
	if _, err := host.WaitSession(context.Background(), sessionState.ID); err != nil {
		t.Fatalf("WaitSession() error = %v", err)
	}
}

func TestHandlerStartSessionOutlivesRequestContext(t *testing.T) {
	readyCh := make(chan struct{})
	releaseCh := make(chan struct{})
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithSessionIDSource(func() string { return "session-detached" }),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "generic-turn",
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
				}, nil
			},
		})),
		withRunnerFactory(func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{run: func(ctx context.Context) error {
				select {
				case <-ctx.Done():
					return ctx.Err()
				case <-releaseCh:
				}
				if cfg.Hooks.OnReady != nil {
					cfg.Hooks.OnReady()
				}
				close(readyCh)
				<-ctx.Done()
				return nil
			}}
		}),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(StartSessionRequest{
		Spec: &ProfileSpec{
			Provider:    "generic-turn",
			Link:        "generic-turn://user:pass@turn.example.test:3478",
			ListenAddr:  reserveUDPAddr(t),
			PeerAddr:    "127.0.0.1:56000",
			Connections: 1,
			Mode:        TransportModeAuto,
			UseDTLS:     boolRef(true),
		},
	})
	reqCtx, cancelReq := context.WithCancel(context.Background())
	req := httptest.NewRequest(http.MethodPost, "/v1/sessions", bytes.NewReader(payload)).WithContext(reqCtx)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("POST /v1/sessions code = %d body=%s", rec.Code, rec.Body.String())
	}

	var sessionState Session
	if err := json.Unmarshal(rec.Body.Bytes(), &sessionState); err != nil {
		t.Fatalf("decode session response: %v", err)
	}

	cancelReq()
	close(releaseCh)

	select {
	case <-readyCh:
	case <-time.After(3 * time.Second):
		t.Fatal("session did not outlive request context cancellation")
	}

	waitForSessionState(t, host, sessionState.ID, SessionStateReady)

	if _, err := host.StopSession(sessionState.ID); err != nil {
		t.Fatalf("StopSession() error = %v", err)
	}
	if _, err := host.WaitSession(context.Background(), sessionState.ID); err != nil {
		t.Fatalf("WaitSession() error = %v", err)
	}
}
