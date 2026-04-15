package tunnelserver

import (
	"context"
	"log/slog"
	"net"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/pion/dtls/v3"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
)

func TestServerObservabilityTracksStartupAndTraffic(t *testing.T) {
	upstreamConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen upstream: %v", err)
	}
	defer upstreamConn.Close()

	upstreamCtx, cancelUpstream := context.WithCancel(context.Background())
	defer cancelUpstream()
	go runUDPEcho(upstreamCtx, upstreamConn)

	handler := newServerCaptureHandler()
	metrics := observe.NewMetrics()
	server, err := New(config.ServerConfig{
		ListenAddr:       "127.0.0.1:0",
		UpstreamAddr:     upstreamConn.LocalAddr().String(),
		HandshakeTimeout: 5 * time.Second,
		IdleTimeout:      5 * time.Second,
	}, slog.New(handler))
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	server.SetMetrics(metrics)

	listener, err := server.Listen()
	if err != nil {
		t.Fatalf("Listen() error = %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	go func() {
		errCh <- server.Serve(ctx, listener)
	}()

	clientConn, endpoint := newOverlayTestClient(t, listener.Addr().String(), overlay.AdapterUDP)
	defer clientConn.Close()

	payload := []byte("server-observe")
	if err := endpoint.WriteFrame(overlay.Frame{
		Kind:    overlay.FrameDatagram,
		RouteID: 1,
		Payload: payload,
	}); err != nil {
		cancel()
		t.Fatalf("write overlay datagram: %v", err)
	}
	_ = clientConn.SetReadDeadline(time.Now().Add(5 * time.Second))
	frame, err := endpoint.ReadFrame()
	if err != nil {
		cancel()
		t.Fatalf("read overlay echo: %v", err)
	}
	if frame.Kind != overlay.FrameDatagram {
		cancel()
		t.Fatalf("frame kind = %s, want %s", frame.Kind, overlay.FrameDatagram)
	}
	if got := string(frame.Payload); got != string(payload) {
		cancel()
		t.Fatalf("echo payload = %q, want %q", got, payload)
	}

	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Serve() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Serve() did not stop")
	}

	if !hasServerRecord(handler.records(), "runtime_startup") {
		t.Fatalf("missing runtime_startup event: %#v", handler.records())
	}
	text := metrics.Prometheus()
	for _, expected := range []string{
		`vk_turn_proxy_runtime_session_starts_total{peer_mode="dtls",provider="none",runtime="server"} 1`,
		`vk_turn_proxy_runtime_forwarded_packets_total{direction="client_to_upstream",provider="none",runtime="server"} 1`,
		`vk_turn_proxy_runtime_forwarded_packets_total{direction="upstream_to_client",provider="none",runtime="server"} 1`,
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("metrics output missing %q:\n%s", expected, text)
		}
	}
}

func TestServerObservabilityTracksUpstreamDialFailureMetric(t *testing.T) {
	handler := newServerCaptureHandler()
	metrics := observe.NewMetrics()
	server, err := New(config.ServerConfig{
		ListenAddr:       "127.0.0.1:0",
		UpstreamAddr:     "127.0.0.1",
		HandshakeTimeout: 5 * time.Second,
		IdleTimeout:      5 * time.Second,
	}, slog.New(handler))
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	server.SetMetrics(metrics)

	listener, err := server.Listen()
	if err != nil {
		t.Fatalf("Listen() error = %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	go func() {
		errCh <- server.Serve(ctx, listener)
	}()

	clientConn, endpoint := newOverlayTestClientWithoutHello(t, listener.Addr().String())
	defer clientConn.Close()
	if err := endpoint.WriteFrame(overlay.Frame{Kind: overlay.FrameHello, Adapter: overlay.AdapterUDP}); err != nil {
		cancel()
		t.Fatalf("write overlay hello: %v", err)
	}
	_, _ = endpoint.ReadFrame()

	deadline := time.After(2 * time.Second)
	for {
		if strings.Contains(metrics.Prometheus(), `vk_turn_proxy_runtime_transport_stage_failures_total{peer_mode="dtls",provider="none",runtime="server",stage="upstream_dial"} 1`) {
			break
		}
		select {
		case <-deadline:
			cancel()
			t.Fatalf("timed out waiting for upstream_dial metric:\n%s", metrics.Prometheus())
		case <-time.After(20 * time.Millisecond):
		}
	}

	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Serve() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Serve() did not stop")
	}

	if !hasServerRecord(handler.records(), "connection_failure") {
		t.Fatalf("missing connection_failure event: %#v", handler.records())
	}
}

func TestServerRejectsUnsupportedOverlayPairing(t *testing.T) {
	upstreamConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen upstream: %v", err)
	}
	defer upstreamConn.Close()

	server, err := New(config.ServerConfig{
		ListenAddr:       "127.0.0.1:0",
		UpstreamAddr:     upstreamConn.LocalAddr().String(),
		Egress:           config.AdapterUDP,
		HandshakeTimeout: 5 * time.Second,
		IdleTimeout:      5 * time.Second,
	}, slog.New(newServerCaptureHandler()))
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}

	listener, err := server.Listen()
	if err != nil {
		t.Fatalf("Listen() error = %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	errCh := make(chan error, 1)
	go func() {
		errCh <- server.Serve(ctx, listener)
	}()

	clientConn, endpoint := newOverlayTestClientWithoutHello(t, listener.Addr().String())
	defer clientConn.Close()

	if err := endpoint.WriteFrame(overlay.Frame{
		Kind:    overlay.FrameHello,
		Adapter: overlay.AdapterTCP,
	}); err != nil {
		t.Fatalf("write overlay hello: %v", err)
	}
	frame, err := endpoint.ReadFrame()
	if err != nil {
		t.Fatalf("read overlay reject: %v", err)
	}
	if frame.Kind != overlay.FrameHelloReject {
		t.Fatalf("frame kind = %s, want %s", frame.Kind, overlay.FrameHelloReject)
	}
	if !strings.Contains(frame.Reason, "unsupported overlay adapter pair") {
		t.Fatalf("unexpected reject reason %q", frame.Reason)
	}

	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Serve() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Serve() did not stop")
	}
}

func TestServerPlainPeerModeRelaysUDPDatagrams(t *testing.T) {
	upstreamConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen upstream: %v", err)
	}
	defer upstreamConn.Close()

	upstreamCtx, cancelUpstream := context.WithCancel(context.Background())
	defer cancelUpstream()
	go runUDPEcho(upstreamCtx, upstreamConn)

	handler := newServerCaptureHandler()
	metrics := observe.NewMetrics()
	server, err := New(config.ServerConfig{
		ListenAddr:       "127.0.0.1:0",
		UpstreamAddr:     upstreamConn.LocalAddr().String(),
		Egress:           config.AdapterUDP,
		PeerMode:         config.ServerPeerModePlain,
		HandshakeTimeout: 5 * time.Second,
		IdleTimeout:      5 * time.Second,
	}, slog.New(handler))
	if err != nil {
		t.Fatalf("New() error = %v", err)
	}
	server.SetMetrics(metrics)

	packetConn, err := server.listenPacket()
	if err != nil {
		t.Fatalf("listenPacket() error = %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	go func() {
		errCh <- server.ServePlain(ctx, packetConn)
	}()

	clientConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		cancel()
		t.Fatalf("listen client: %v", err)
	}
	defer clientConn.Close()

	payload := []byte("plain-wg-datagram")
	if _, err := clientConn.WriteTo(payload, packetConn.LocalAddr()); err != nil {
		cancel()
		t.Fatalf("write plain datagram: %v", err)
	}

	buf := make([]byte, 1600)
	_ = clientConn.SetReadDeadline(time.Now().Add(5 * time.Second))
	n, _, err := clientConn.ReadFrom(buf)
	if err != nil {
		cancel()
		t.Fatalf("read plain echo: %v", err)
	}
	if got := string(buf[:n]); got != string(payload) {
		cancel()
		t.Fatalf("echo payload = %q, want %q", got, payload)
	}

	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("ServePlain() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("ServePlain() did not stop")
	}

	text := metrics.Prometheus()
	for _, expected := range []string{
		`vk_turn_proxy_runtime_session_starts_total{peer_mode="plain",provider="none",runtime="server"} 1`,
		`vk_turn_proxy_runtime_forwarded_packets_total{direction="client_to_upstream",provider="none",runtime="server"} 1`,
		`vk_turn_proxy_runtime_forwarded_packets_total{direction="upstream_to_client",provider="none",runtime="server"} 1`,
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("metrics output missing %q:\n%s", expected, text)
		}
	}
}

func runUDPEcho(ctx context.Context, conn net.PacketConn) {
	buf := make([]byte, 1600)
	for {
		_ = conn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
		n, addr, err := conn.ReadFrom(buf)
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
				continue
			}
			return
		}
		_, _ = conn.WriteTo(buf[:n], addr)
	}
}

type serverCapturedRecord struct {
	message string
	attrs   map[string]any
}

type serverCaptureHandler struct {
	state *serverCaptureState
	attrs []slog.Attr
}

type serverCaptureState struct {
	mu   sync.Mutex
	logs []serverCapturedRecord
}

func newServerCaptureHandler() *serverCaptureHandler {
	return &serverCaptureHandler{state: &serverCaptureState{}}
}

func (h *serverCaptureHandler) Enabled(context.Context, slog.Level) bool { return true }

func (h *serverCaptureHandler) Handle(_ context.Context, record slog.Record) error {
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
	h.state.logs = append(h.state.logs, serverCapturedRecord{message: record.Message, attrs: attrs})
	return nil
}

func (h *serverCaptureHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &serverCaptureHandler{
		state: h.state,
		attrs: append(append([]slog.Attr(nil), h.attrs...), attrs...),
	}
}

func (h *serverCaptureHandler) WithGroup(string) slog.Handler { return h }

func (h *serverCaptureHandler) records() []serverCapturedRecord {
	h.state.mu.Lock()
	defer h.state.mu.Unlock()
	out := make([]serverCapturedRecord, len(h.state.logs))
	copy(out, h.state.logs)
	return out
}

func hasServerRecord(records []serverCapturedRecord, message string) bool {
	for _, record := range records {
		if record.message == message {
			return true
		}
	}

	return false
}

func newOverlayTestClient(t *testing.T, serverAddr string, ingress overlay.AdapterKind) (*dtls.Conn, *overlay.Endpoint) {
	t.Helper()

	clientConn, endpoint := newOverlayTestClientWithoutHello(t, serverAddr)
	if err := endpoint.WriteFrame(overlay.Frame{
		Kind:    overlay.FrameHello,
		Adapter: ingress,
	}); err != nil {
		_ = clientConn.Close()
		t.Fatalf("write overlay hello: %v", err)
	}
	frame, err := endpoint.ReadFrame()
	if err != nil {
		_ = clientConn.Close()
		t.Fatalf("read overlay hello ack: %v", err)
	}
	if frame.Kind != overlay.FrameHelloAck {
		_ = clientConn.Close()
		t.Fatalf("frame kind = %s, want %s", frame.Kind, overlay.FrameHelloAck)
	}

	return clientConn, endpoint
}

func newOverlayTestClientWithoutHello(t *testing.T, serverAddr string) (*dtls.Conn, *overlay.Endpoint) {
	t.Helper()

	localConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen local packet conn: %v", err)
	}

	peerAddr, err := net.ResolveUDPAddr("udp", serverAddr)
	if err != nil {
		_ = localConn.Close()
		t.Fatalf("resolve peer addr: %v", err)
	}

	clientConn, err := dtls.Client(localConn, peerAddr, &dtls.Config{
		InsecureSkipVerify:   true,
		ExtendedMasterSecret: dtls.RequireExtendedMasterSecret,
		CipherSuites:         []dtls.CipherSuiteID{dtls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256},
	})
	if err != nil {
		_ = localConn.Close()
		t.Fatalf("dtls client: %v", err)
	}

	handshakeCtx, cancelHandshake := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancelHandshake()
	if err := clientConn.HandshakeContext(handshakeCtx); err != nil {
		_ = clientConn.Close()
		t.Fatalf("handshake: %v", err)
	}

	return clientConn, overlay.NewEndpoint(clientConn, slog.Default())
}
