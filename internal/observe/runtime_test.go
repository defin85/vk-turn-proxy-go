package observe

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestObserverSanitizesSensitiveAttrs(t *testing.T) {
	handler := newCaptureHandler()
	observer := NewObserver(RuntimeClient, slog.New(handler), NewMetrics(), Metadata{
		SessionID: "session-1",
		Provider:  "vk",
		TURNMode:  "udp",
		PeerMode:  "dtls",
	})

	observer.Emit(context.Background(), slog.LevelError, "runtime_failure",
		"stage", "provider_resolve",
		"result", "failed",
		"error", `unexpected invite https://vk.com/call/join/secret-token and turn=generic-turn://alice:s3cret@turn.example.test:3478 access_token=real-token`,
	)

	records := handler.records()
	if len(records) != 1 {
		t.Fatalf("record count = %d, want 1", len(records))
	}
	record := records[0]
	if got := record.attrs["event"]; got != "runtime_failure" {
		t.Fatalf("event = %#v", got)
	}
	if got := record.attrs["runtime"]; got != RuntimeClient {
		t.Fatalf("runtime = %#v", got)
	}
	if got := record.attrs["session_id"]; got != "session-1" {
		t.Fatalf("session_id = %#v", got)
	}
	errorText, _ := record.attrs["error"].(string)
	for _, secret := range []string{"secret-token", "alice", "s3cret", "real-token"} {
		if strings.Contains(errorText, secret) {
			t.Fatalf("sanitized error leaked %q: %s", secret, errorText)
		}
	}
	for _, placeholder := range []string{
		"<redacted:invite-token>",
		"<redacted:turn-username>",
		"<redacted:turn-password>",
		"<redacted:access-token>",
	} {
		if !strings.Contains(errorText, placeholder) {
			t.Fatalf("sanitized error missing %q: %s", placeholder, errorText)
		}
	}
}

func TestMetricsPrometheusExportsDocumentedFamilies(t *testing.T) {
	metrics := NewMetrics()
	metrics.IncSessionStarts(RuntimeClient, "generic-turn", "udp", "dtls")
	metrics.IncSessionFailures(RuntimeClient, "generic-turn", "udp", "dtls", "provider_resolve")
	metrics.IncStartupStageFailures(RuntimeClient, "generic-turn", "udp", "dtls", "provider_resolve")
	metrics.IncTransportStageFailures(RuntimeClient, "generic-turn", "udp", "dtls", "turn_dial")
	metrics.SetActiveWorkers(RuntimeClient, "generic-turn", "udp", "dtls", 2)
	metrics.AddForwardedTraffic(RuntimeClient, "generic-turn", "local_to_relay", 11)

	text := metrics.Prometheus()
	for _, expected := range []string{
		"vk_turn_proxy_runtime_session_starts_total",
		`runtime="client"`,
		`provider="generic-turn"`,
		`turn_mode="udp"`,
		`peer_mode="dtls"`,
		`stage="provider_resolve"`,
		`vk_turn_proxy_runtime_transport_stage_failures_total`,
		`stage="turn_dial"`,
		"vk_turn_proxy_runtime_active_workers",
		"vk_turn_proxy_runtime_forwarded_packets_total",
		"vk_turn_proxy_runtime_forwarded_bytes_total",
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("metrics output missing %q:\n%s", expected, text)
		}
	}
	if strings.Contains(text, "session_id") {
		t.Fatalf("metrics output leaked high-cardinality session_id:\n%s", text)
	}
}

func TestStartMetricsServerServesPrometheus(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	metrics := NewMetrics()
	metrics.IncSessionStarts(RuntimeServer, "none", "", "dtls")
	addr, err := StartMetricsServer(ctx, "127.0.0.1:0", metrics, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatalf("StartMetricsServer() error = %v", err)
	}
	if addr == nil {
		t.Fatal("expected listen addr")
	}

	client := &http.Client{Timeout: 2 * time.Second}
	response, err := client.Get("http://" + addr.String() + "/metrics")
	if err != nil {
		t.Fatalf("GET /metrics: %v", err)
	}
	defer response.Body.Close()

	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatalf("read body: %v", err)
	}
	if got := response.Header.Get("Content-Type"); !strings.Contains(got, "text/plain") {
		t.Fatalf("content-type = %q", got)
	}
	if !strings.Contains(string(body), "vk_turn_proxy_runtime_session_starts_total") {
		t.Fatalf("metrics body missing family:\n%s", body)
	}
}

type capturedRecord struct {
	message string
	attrs   map[string]any
}

type captureHandler struct {
	state *captureState
	attrs []slog.Attr
}

type captureState struct {
	mu   sync.Mutex
	logs []capturedRecord
}

func newCaptureHandler() *captureHandler {
	return &captureHandler{state: &captureState{}}
}

func (h *captureHandler) Enabled(context.Context, slog.Level) bool { return true }

func (h *captureHandler) Handle(_ context.Context, record slog.Record) error {
	attrs := make(map[string]any, len(h.attrs)+record.NumAttrs())
	for _, attr := range h.attrs {
		attrs[attr.Key] = attr.Value.Any()
	}
	record.Attrs(func(attr slog.Attr) bool {
		attrs[attr.Key] = attr.Value.Any()
		return true
	})

	h.state.mu.Lock()
	defer h.state.mu.Unlock()
	h.state.logs = append(h.state.logs, capturedRecord{message: record.Message, attrs: attrs})
	return nil
}

func (h *captureHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &captureHandler{
		state: h.state,
		attrs: append(append([]slog.Attr(nil), h.attrs...), attrs...),
	}
}

func (h *captureHandler) WithGroup(string) slog.Handler { return h }

func (h *captureHandler) records() []capturedRecord {
	h.state.mu.Lock()
	defer h.state.mu.Unlock()
	out := make([]capturedRecord, len(h.state.logs))
	copy(out, h.state.logs)
	return out
}
