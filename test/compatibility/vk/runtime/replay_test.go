package vkruntime_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	vkprovider "github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/session"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
	"github.com/defin85/vk-turn-proxy-go/test/turnlab"
)

const (
	vkLoginAnonymTokenURL  = "https://login.vk.ru/?act=get_anonym_token"
	vkGetAnonymousTokenURL = "https://api.vk.ru/method/calls.getAnonymousToken?v=5.274&client_id=6287487"
	vkOKAPIURL             = "https://calls.okcdn.ru/fb.do"
)

type replayProviderFixture struct {
	ScenarioID string                `json:"scenario_id"`
	Stages     []replayProviderStage `json:"stages"`
	Expected   struct {
		Resolution struct {
			Username string `json:"username_redacted"`
			Password string `json:"password_redacted"`
			Address  string `json:"address"`
		} `json:"resolution"`
	} `json:"expected"`
}

type replayProviderStage struct {
	EndpointID string `json:"endpoint_id"`
	Request    struct {
		FormKeys []string `json:"form_keys"`
	} `json:"request"`
	Response struct {
		StatusCode int            `json:"status_code"`
		Body       map[string]any `json:"body"`
	} `json:"response"`
}

type replayFixtureDoer struct {
	mu     sync.Mutex
	stages []replayProviderStage
	calls  int
}

func TestRuntimeEvidenceReplay(t *testing.T) {
	fixtures := []string{
		"vk_runtime_success_v1.json",
		"vk_runtime_failure_v1.json",
		"vk_runtime_tcp_dtls_success_v1.json",
		"vk_runtime_udp_plain_success_v1.json",
		"vk_runtime_tcp_plain_success_v1.json",
		"vk_runtime_bind_target_success_v1.json",
		"vk_runtime_auto_plain_success_v1.json",
		"vk_runtime_auto_bind_success_v1.json",
	}

	for _, name := range fixtures {
		name := name
		t.Run(strings.TrimSuffix(name, ".json"), func(t *testing.T) {
			asset := loadRuntimeEvidenceAsset(t, filepath.Join("fixtures", name))
			verifyRuntimeReplay(t, asset)
		})
	}
}

func verifyRuntimeReplay(t *testing.T, asset evidenceAsset) {
	t.Helper()

	providerFixture := loadReplayProviderFixture(t, asset.Replay.ProviderFixture)
	doer := &replayFixtureDoer{stages: providerFixture.Stages}

	harnessCtx, cancelHarness := context.WithCancel(context.Background())
	harness, err := turnlab.StartWithOptions(harnessCtx, testLogger(), turnlab.Options{
		AcceptedCredentials: []turnlab.TURNCredentials{
			{
				Username: providerFixture.Expected.Resolution.Username,
				Password: providerFixture.Expected.Resolution.Password,
			},
		},
	})
	if err != nil {
		t.Fatalf("start turnlab harness: %v", err)
	}
	t.Cleanup(func() {
		cancelHarness()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	cfg, cleanupPeer := materializeReplayConfig(t, asset, harness)
	t.Cleanup(cleanupPeer)

	registry := provider.NewRegistry(vkprovider.NewWithHTTPDoer(doer))
	recorder := &turnBaseRecorder{}
	var newRunner session.RunnerFactory
	if asset.Replay.ExpectTURNBaseIP != "" {
		newRunner = recorder.RunnerFactory()
	}
	result := runReplayScenario(t, asset, cfg, registry, newRunner)

	if result.exitCode != asset.Rewrite.ExitCode {
		t.Fatalf("rewrite exit_code = %d, want %d", result.exitCode, asset.Rewrite.ExitCode)
	}
	if result.forwardingRoundTrip != asset.Rewrite.ForwardingRoundTrip {
		t.Fatalf("rewrite forwarding_round_trip = %v, want %v", result.forwardingRoundTrip, asset.Rewrite.ForwardingRoundTrip)
	}
	if result.stage != asset.Rewrite.ErrorStage {
		t.Fatalf("rewrite error_stage = %q, want %q", result.stage, asset.Rewrite.ErrorStage)
	}
	if asset.Replay.ExpectTURNBaseIP != "" {
		if got := addrIPString(recorder.Addr()); got != asset.Replay.ExpectTURNBaseIP {
			t.Fatalf("rewrite turn base ip = %q, want %q", got, asset.Replay.ExpectTURNBaseIP)
		}
	}

	wantResult := asset.Rewrite.Result
	if result.exitCode == 0 && wantResult != "success" {
		t.Fatalf("rewrite result mismatch: got success, want %s", wantResult)
	}
	if result.exitCode != 0 && wantResult != "failure" {
		t.Fatalf("rewrite result mismatch: got failure, want %s", wantResult)
	}

	if calls := doer.CallCount(); calls != len(providerFixture.Stages) {
		t.Fatalf("provider call count = %d, want %d", calls, len(providerFixture.Stages))
	}
}

type replayResult struct {
	exitCode            int
	stage               string
	forwardingRoundTrip bool
}

func runReplayScenario(
	t *testing.T,
	asset evidenceAsset,
	cfg config.ClientConfig,
	registry *provider.Registry,
	newRunner session.RunnerFactory,
) replayResult {
	t.Helper()

	switch asset.Kind {
	case "runtime_success":
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()

		errCh := make(chan error, 1)
		go func() {
			errCh <- session.Run(ctx, cfg, session.Dependencies{
				Registry:  registry,
				Logger:    testLogger(),
				NewRunner: newRunner,
				SessionID: session.NewID(),
			})
		}()

		clientConn, err := net.Dial("udp", cfg.ListenAddr)
		if err != nil {
			cancel()
			t.Fatalf("dial local client addr: %v", err)
		}
		defer clientConn.Close()

		mustEchoEventually(t, clientConn, []byte(asset.ScenarioID))
		cancel()

		select {
		case err := <-errCh:
			return replayResult{
				exitCode:            deriveExitCode(err),
				stage:               stageString(err),
				forwardingRoundTrip: err == nil,
			}
		case <-time.After(5 * time.Second):
			t.Fatal("session did not stop after cancellation")
			return replayResult{}
		}
	case "runtime_failure":
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()

		err := session.Run(ctx, cfg, session.Dependencies{
			Registry:  registry,
			Logger:    testLogger(),
			NewRunner: newRunner,
			SessionID: session.NewID(),
		})
		if err == nil {
			t.Fatal("expected runtime failure")
		}

		return replayResult{
			exitCode:            deriveExitCode(err),
			stage:               stageString(err),
			forwardingRoundTrip: false,
		}
	default:
		t.Fatalf("unsupported asset kind %q", asset.Kind)
		return replayResult{}
	}
}

func materializeReplayConfig(t *testing.T, asset evidenceAsset, harness *turnlab.Harness) (config.ClientConfig, func()) {
	t.Helper()

	peerAddr, cleanup := materializeReplayPeer(t, asset.Input.PeerAddrRedacted, harness)

	return config.ClientConfig{
		Provider:      "vk",
		Link:          asset.Input.InviteRedacted,
		ListenAddr:    reserveUDPAddr(t),
		PeerAddr:      peerAddr,
		Connections:   asset.Slice.Connections,
		TURNServer:    materializeReplayTURNValue(t, asset.Input.TURNOverride, harness),
		TURNPort:      materializeReplayTURNValue(t, asset.Input.PortOverride, harness),
		BindInterface: asset.Slice.BindInterface,
		Mode:          config.TransportMode(asset.Slice.Mode),
		UseDTLS:       asset.Slice.DTLS,
	}, cleanup
}

func materializeReplayPeer(t *testing.T, placeholder string, harness *turnlab.Harness) (string, func()) {
	t.Helper()

	switch placeholder {
	case runtimePeerTurnlab:
		return harness.Descriptor.PeerAddress, func() {}
	case runtimePeerTurnlabUpstream:
		return harness.Descriptor.UpstreamAddress, func() {}
	case runtimePeerPlainUDP:
		conn, err := net.ListenPacket("udp4", "127.0.0.1:0")
		if err != nil {
			t.Fatalf("listen plain udp peer: %v", err)
		}

		return conn.LocalAddr().String(), func() {
			_ = conn.Close()
		}
	default:
		t.Fatalf("unsupported replay peer placeholder %q", placeholder)
		return "", func() {}
	}
}

func materializeReplayTURNValue(t *testing.T, placeholder string, harness *turnlab.Harness) string {
	t.Helper()

	switch placeholder {
	case runtimeTurnHost:
		host, _, err := net.SplitHostPort(harness.Descriptor.TURNAddress)
		if err != nil {
			t.Fatalf("split turn udp address: %v", err)
		}
		return host
	case runtimeTurnPort:
		_, port, err := net.SplitHostPort(harness.Descriptor.TURNAddress)
		if err != nil {
			t.Fatalf("split turn udp address: %v", err)
		}
		return port
	case runtimeTurnTCPHost:
		host, _, err := net.SplitHostPort(harness.Descriptor.TURNTCPAddress)
		if err != nil {
			t.Fatalf("split turn tcp address: %v", err)
		}
		return host
	case runtimeTurnTCPPort:
		_, port, err := net.SplitHostPort(harness.Descriptor.TURNTCPAddress)
		if err != nil {
			t.Fatalf("split turn tcp address: %v", err)
		}
		return port
	default:
		t.Fatalf("unsupported replay turn placeholder %q", placeholder)
		return ""
	}
}

type turnBaseRecorder struct {
	mu   sync.Mutex
	addr net.Addr
}

func (r *turnBaseRecorder) RunnerFactory() session.RunnerFactory {
	return func(cfg transport.ClientConfig) transport.Runner {
		cfg.Hooks.OnTURNBaseBind = func(addr net.Addr) {
			r.set(addr)
		}
		return transport.NewClientRunner(cfg)
	}
}

func (r *turnBaseRecorder) set(addr net.Addr) {
	if addr == nil {
		return
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.addr = cloneReplayAddr(addr)
}

func (r *turnBaseRecorder) Addr() net.Addr {
	r.mu.Lock()
	defer r.mu.Unlock()
	return cloneReplayAddr(r.addr)
}

func cloneReplayAddr(addr net.Addr) net.Addr {
	switch value := addr.(type) {
	case *net.UDPAddr:
		if value == nil {
			return nil
		}
		cloned := *value
		cloned.IP = append(net.IP(nil), value.IP...)
		return &cloned
	case *net.TCPAddr:
		if value == nil {
			return nil
		}
		cloned := *value
		cloned.IP = append(net.IP(nil), value.IP...)
		return &cloned
	default:
		return addr
	}
}

func loadRuntimeEvidenceAsset(t *testing.T, relativePath string) evidenceAsset {
	t.Helper()

	data, err := os.ReadFile(relativePath)
	if err != nil {
		t.Fatalf("read runtime evidence asset %s: %v", relativePath, err)
	}

	var asset evidenceAsset
	if err := json.Unmarshal(data, &asset); err != nil {
		t.Fatalf("decode runtime evidence asset %s: %v", relativePath, err)
	}

	return asset
}

func loadReplayProviderFixture(t *testing.T, name string) replayProviderFixture {
	t.Helper()

	path := filepath.Join("..", "fixtures", name)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read provider fixture %s: %v", name, err)
	}

	var fixture replayProviderFixture
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatalf("decode provider fixture %s: %v", name, err)
	}

	return fixture
}

func (d *replayFixtureDoer) Do(request *http.Request) (*http.Response, error) {
	d.mu.Lock()
	defer d.mu.Unlock()

	if d.calls >= len(d.stages) {
		return nil, fmt.Errorf("unexpected extra HTTP call to %s", request.URL.String())
	}

	stage := d.stages[d.calls]
	d.calls++

	if request.Method != http.MethodPost {
		return nil, fmt.Errorf("unexpected method for stage %s: %s", stage.EndpointID, request.Method)
	}
	if got, want := request.URL.String(), replayEndpointURL(stage.EndpointID); got != want {
		return nil, fmt.Errorf("unexpected URL for stage %s: got %s want %s", stage.EndpointID, got, want)
	}
	if err := request.ParseForm(); err != nil {
		return nil, fmt.Errorf("parse form for stage %s: %w", stage.EndpointID, err)
	}
	for _, key := range stage.Request.FormKeys {
		if _, ok := request.PostForm[key]; !ok {
			return nil, fmt.Errorf("stage %s missing form key %q", stage.EndpointID, key)
		}
	}

	body, err := json.Marshal(stage.Response.Body)
	if err != nil {
		return nil, fmt.Errorf("marshal response body for stage %s: %w", stage.EndpointID, err)
	}

	return &http.Response{
		StatusCode: stage.Response.StatusCode,
		Status:     http.StatusText(stage.Response.StatusCode),
		Body:       io.NopCloser(bytes.NewReader(body)),
		Header:     make(http.Header),
	}, nil
}

func (d *replayFixtureDoer) CallCount() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.calls
}

func replayEndpointURL(endpointID string) string {
	switch endpointID {
	case "vk_login_anonym_token":
		return vkLoginAnonymTokenURL
	case "vk_calls_get_anonymous_token":
		return vkGetAnonymousTokenURL
	case "ok_anonym_login", "ok_join_conversation_by_link":
		return vkOKAPIURL
	default:
		return ""
	}
}

func mustEchoEventually(t *testing.T, conn net.Conn, payload []byte) {
	t.Helper()

	buf := make([]byte, 1600)
	deadline := time.Now().Add(5 * time.Second)

	for time.Now().Before(deadline) {
		if err := conn.SetDeadline(time.Now().Add(200 * time.Millisecond)); err != nil {
			t.Fatalf("set deadline: %v", err)
		}
		if _, err := conn.Write(payload); err != nil {
			continue
		}

		n, err := conn.Read(buf)
		if err != nil {
			continue
		}
		if got := string(buf[:n]); got != string(payload) {
			t.Fatalf("unexpected payload: got %q want %q", got, payload)
		}

		return
	}

	t.Fatalf("timed out waiting for echo %q", payload)
}

func reserveUDPAddr(t *testing.T) string {
	t.Helper()

	conn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("reserve udp addr: %v", err)
	}
	addr := conn.LocalAddr().String()
	if err := conn.Close(); err != nil {
		t.Fatalf("close reserved udp addr: %v", err)
	}

	return addr
}

func deriveExitCode(err error) int {
	if err == nil {
		return 0
	}
	if errors.Is(err, provider.ErrNotImplemented) {
		return 3
	}

	return 1
}

func stageString(err error) string {
	if err == nil {
		return ""
	}

	stage, ok := runstage.FromError(err)
	if !ok {
		return ""
	}

	return string(stage)
}

func addrIPString(addr net.Addr) string {
	switch value := addr.(type) {
	case *net.UDPAddr:
		if value == nil {
			return ""
		}
		return value.IP.String()
	case *net.TCPAddr:
		if value == nil {
			return ""
		}
		return value.IP.String()
	default:
		return ""
	}
}

func testLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}
