package turnlab_test

import (
	"bytes"
	"context"
	"errors"
	"net"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/pion/dtls/v3"
	"github.com/pion/turn/v5"

	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
	"github.com/defin85/vk-turn-proxy-go/test/turnlab"
)

func TestHarnessRelayRoundTrip(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	harness, err := turnlab.Start(ctx, nil)
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancel()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	if harness.Descriptor.TURNAddress == "" {
		t.Fatal("turn address is empty")
	}
	if harness.Descriptor.TURNTCPAddress == "" {
		t.Fatal("turn tcp address is empty")
	}
	if harness.Descriptor.PeerAddress == "" {
		t.Fatal("peer address is empty")
	}
	if harness.Descriptor.UpstreamAddress == "" {
		t.Fatal("upstream address is empty")
	}
	if link := harness.GenericTurnLink(); !strings.HasPrefix(link, "generic-turn://") {
		t.Fatalf("unexpected generic-turn link: %q", link)
	}

	dtlsConn, endpoint, _, cleanup := dialHarnessDTLS(t, harness, "udp")
	t.Cleanup(cleanup)

	mustReadDTLSEcho(t, dtlsConn, endpoint, []byte("turn-lab-smoke"))
}

func TestHarnessTCPRelayRoundTrip(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	harness, err := turnlab.Start(ctx, nil)
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancel()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	dtlsConn, endpoint, _, cleanup := dialHarnessDTLS(t, harness, "tcp")
	t.Cleanup(cleanup)

	mustReadDTLSEcho(t, dtlsConn, endpoint, []byte("turn-lab-tcp-smoke"))
}

func TestHarnessRelayRoundTripAfterAllocationRefresh(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	harness, err := turnlab.StartWithOptions(ctx, nil, turnlab.Options{
		AllocationLifetime: 2 * time.Second,
	})
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancel()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	dtlsConn, endpoint, _, cleanup := dialHarnessDTLS(t, harness, "udp")
	t.Cleanup(cleanup)

	mustReadDTLSEcho(t, dtlsConn, endpoint, []byte("before-refresh"))

	waitCtx, waitCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer waitCancel()
	if err := harness.WaitRefreshCount(waitCtx, 1); err != nil {
		t.Fatalf("wait refresh count: %v", err)
	}
	if got := harness.RefreshCount(); got < 1 {
		t.Fatalf("refresh count = %d, want >= 1", got)
	}

	mustReadDTLSEcho(t, dtlsConn, endpoint, []byte("after-refresh"))
}

func TestHarnessCustomPeerIdleTimeoutClosesIdleDTLSSession(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	harness, err := turnlab.StartWithOptions(ctx, nil, turnlab.Options{
		PeerIdleTimeout: 100 * time.Millisecond,
	})
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancel()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	dtlsConn, _, _, cleanup := dialHarnessDTLS(t, harness, "udp")
	t.Cleanup(cleanup)

	waitForIdleClose(t, dtlsConn, 2*time.Second)
}

func TestHarnessPlainRelayRoundTrip(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	harness, err := turnlab.Start(ctx, nil)
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancel()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	relayConn, cleanup := dialHarnessRelay(t, harness, "udp")
	t.Cleanup(cleanup)

	upstreamAddr, err := net.ResolveUDPAddr("udp", harness.Descriptor.UpstreamAddress)
	if err != nil {
		t.Fatalf("resolve upstream addr: %v", err)
	}

	payload := []byte("turn-lab-plain")
	if err := relayConn.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatalf("set deadline: %v", err)
	}
	if _, err := relayConn.WriteTo(payload, upstreamAddr); err != nil {
		t.Fatalf("write payload: %v", err)
	}

	buf := make([]byte, 64)
	n, _, err := relayConn.ReadFrom(buf)
	if err != nil {
		t.Fatalf("read payload: %v", err)
	}
	if !bytes.Equal(buf[:n], payload) {
		t.Fatalf("unexpected payload: got %q want %q", buf[:n], payload)
	}
}

func TestHarnessCleanupReleasesPorts(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	harness, err := turnlab.Start(ctx, nil)
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	_, _, relayAddr, cleanup := dialHarnessDTLS(t, harness, "udp")
	t.Cleanup(cleanup)

	cancel()
	if err := harness.Close(); err != nil {
		t.Fatalf("close harness: %v", err)
	}

	for _, addr := range []string{
		harness.Descriptor.TURNAddress,
		harness.Descriptor.PeerAddress,
		harness.Descriptor.UpstreamAddress,
		relayAddr,
	} {
		conn, err := net.ListenPacket("udp4", addr)
		if err != nil {
			t.Fatalf("rebind %s: %v", addr, err)
		}
		if err := conn.Close(); err != nil {
			t.Fatalf("close rebound conn for %s: %v", addr, err)
		}
	}

	listener, err := net.Listen("tcp4", harness.Descriptor.TURNTCPAddress)
	if err != nil {
		t.Fatalf("rebind %s: %v", harness.Descriptor.TURNTCPAddress, err)
	}
	if err := listener.Close(); err != nil {
		t.Fatalf("close rebound listener for %s: %v", harness.Descriptor.TURNTCPAddress, err)
	}
}

func TestHarnessSupportsSplitBindAndAdvertiseAddresses(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	harness, err := turnlab.StartWithOptions(ctx, nil, turnlab.Options{
		BindAddress:      "0.0.0.0",
		AdvertiseAddress: "127.0.0.1",
	})
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancel()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	if got, want := hostPart(t, harness.Descriptor.TURNAddress), "127.0.0.1"; got != want {
		t.Fatalf("TURNAddress host = %q, want %q", got, want)
	}
	if got, want := hostPart(t, harness.Descriptor.PeerAddress), "127.0.0.1"; got != want {
		t.Fatalf("PeerAddress host = %q, want %q", got, want)
	}
	if link := harness.GenericTurnLink(); !strings.Contains(link, "@127.0.0.1:") {
		t.Fatalf("unexpected generic-turn link %q", link)
	}

	dtlsConn, endpoint, _, cleanup := dialHarnessDTLS(t, harness, "udp")
	t.Cleanup(cleanup)
	mustReadDTLSEcho(t, dtlsConn, endpoint, []byte("turn-lab-split-addresses"))
}

func TestHarnessSupportsFixedPorts(t *testing.T) {
	turnPort := reserveUDPPort(t)
	turnTCPPort := reserveTCPPort(t)
	peerPort := reserveUDPPort(t)

	ctx, cancel := context.WithCancel(context.Background())
	harness, err := turnlab.StartWithOptions(ctx, nil, turnlab.Options{
		BindAddress:      "127.0.0.1",
		AdvertiseAddress: "127.0.0.1",
		TURNPort:         turnPort,
		TURNTCPPort:      turnTCPPort,
		PeerPort:         peerPort,
	})
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancel()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	if got, want := harness.Descriptor.TURNAddress, net.JoinHostPort("127.0.0.1", strconv.Itoa(turnPort)); got != want {
		t.Fatalf("TURNAddress = %q, want %q", got, want)
	}
	if got, want := harness.Descriptor.TURNTCPAddress, net.JoinHostPort("127.0.0.1", strconv.Itoa(turnTCPPort)); got != want {
		t.Fatalf("TURNTCPAddress = %q, want %q", got, want)
	}
	if got, want := harness.Descriptor.PeerAddress, net.JoinHostPort("127.0.0.1", strconv.Itoa(peerPort)); got != want {
		t.Fatalf("PeerAddress = %q, want %q", got, want)
	}

	dtlsConn, endpoint, _, cleanup := dialHarnessDTLS(t, harness, "tcp")
	t.Cleanup(cleanup)
	mustReadDTLSEcho(t, dtlsConn, endpoint, []byte("turn-lab-fixed-ports"))
}

func TestHarnessRejectsNonIPv4AdvertiseAddress(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	harness, err := turnlab.StartWithOptions(ctx, nil, turnlab.Options{
		AdvertiseAddress: "turn.example.test",
	})
	if err == nil {
		if harness != nil {
			_ = harness.Close()
		}
		t.Fatal("expected start to fail for non-ip advertise address")
	}
	if !strings.Contains(err.Error(), "must be an IPv4 literal") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestHarnessStartRejectsCanceledContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	harness, err := turnlab.Start(ctx, nil)
	if err == nil {
		if harness != nil {
			_ = harness.Close()
		}
		t.Fatal("expected start to fail for canceled context")
	}
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected context.Canceled, got %v", err)
	}
	if harness != nil {
		t.Fatal("expected nil harness on canceled context")
	}
}

func TestHarnessRejectsNegativePeerIdleTimeout(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	harness, err := turnlab.StartWithOptions(ctx, nil, turnlab.Options{
		PeerIdleTimeout: -time.Second,
	})
	if err == nil {
		if harness != nil {
			_ = harness.Close()
		}
		t.Fatal("expected start to fail for negative peer idle timeout")
	}
	if !strings.Contains(err.Error(), "peer idle timeout must be positive") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestHarnessRejectsOutOfRangeFixedPort(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	harness, err := turnlab.StartWithOptions(ctx, nil, turnlab.Options{
		TURNTCPPort: 70000,
	})
	if err == nil {
		if harness != nil {
			_ = harness.Close()
		}
		t.Fatal("expected start to fail for out-of-range fixed port")
	}
	if !strings.Contains(err.Error(), "turn tcp port 70000 must be between 0 and 65535") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func dialHarnessDTLS(t *testing.T, harness *turnlab.Harness, turnNetwork string) (*dtls.Conn, *overlay.Endpoint, string, func()) {
	t.Helper()

	relayConn, cleanup := dialHarnessRelay(t, harness, turnNetwork)
	peerAddr, err := net.ResolveUDPAddr("udp", harness.Descriptor.PeerAddress)
	if err != nil {
		cleanup()
		t.Fatalf("resolve peer address: %v", err)
	}

	dtlsConn, err := dtls.Client(relayConn, peerAddr, &dtls.Config{
		InsecureSkipVerify:   true,
		ExtendedMasterSecret: dtls.RequireExtendedMasterSecret,
	})
	if err != nil {
		cleanup()
		t.Fatalf("create dtls client: %v", err)
	}

	handshakeCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := dtlsConn.HandshakeContext(handshakeCtx); err != nil {
		_ = dtlsConn.Close()
		cleanup()
		t.Fatalf("dtls handshake: %v", err)
	}

	endpoint := overlay.NewEndpoint(dtlsConn, nil)
	if err := endpoint.WriteFrame(overlay.Frame{
		Kind:    overlay.FrameHello,
		Adapter: overlay.AdapterUDP,
	}); err != nil {
		_ = dtlsConn.Close()
		cleanup()
		t.Fatalf("write overlay hello: %v", err)
	}
	frame, err := endpoint.ReadFrame()
	if err != nil {
		_ = dtlsConn.Close()
		cleanup()
		t.Fatalf("read overlay hello ack: %v", err)
	}
	if frame.Kind != overlay.FrameHelloAck {
		_ = dtlsConn.Close()
		cleanup()
		t.Fatalf("overlay frame kind = %s, want %s", frame.Kind, overlay.FrameHelloAck)
	}

	return dtlsConn, endpoint, relayConn.LocalAddr().String(), func() {
		_ = dtlsConn.Close()
		cleanup()
	}
}

func mustReadDTLSEcho(t *testing.T, conn *dtls.Conn, endpoint *overlay.Endpoint, payload []byte) {
	t.Helper()

	if err := conn.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatalf("set deadline: %v", err)
	}
	if err := endpoint.WriteFrame(overlay.Frame{
		Kind:    overlay.FrameDatagram,
		RouteID: 1,
		Payload: payload,
	}); err != nil {
		t.Fatalf("write overlay payload: %v", err)
	}

	frame, err := endpoint.ReadFrame()
	if err != nil {
		t.Fatalf("read payload: %v", err)
	}
	if frame.Kind != overlay.FrameDatagram {
		t.Fatalf("frame kind = %s, want %s", frame.Kind, overlay.FrameDatagram)
	}
	if !bytes.Equal(frame.Payload, payload) {
		t.Fatalf("unexpected payload: got %q want %q", frame.Payload, payload)
	}
}

func dialHarnessRelay(t *testing.T, harness *turnlab.Harness, turnNetwork string) (net.PacketConn, func()) {
	t.Helper()

	client, baseConn, cleanup := newHarnessTURNClient(t, harness, turnNetwork)
	if err := client.Listen(); err != nil {
		cleanup()
		t.Fatalf("listen turn client: %v", err)
	}

	relayConn, err := client.Allocate()
	if err != nil {
		cleanup()
		t.Fatalf("allocate relay: %v", err)
	}

	return relayConn, func() {
		_ = relayConn.Close()
		client.Close()
		closeBaseConn(baseConn)
	}
}

func newHarnessTURNClient(t *testing.T, harness *turnlab.Harness, turnNetwork string) (*turn.Client, net.PacketConn, func()) {
	t.Helper()

	baseConn, turnAddr := newHarnessTURNBaseConn(t, harness, turnNetwork)
	client, err := turn.NewClient(&turn.ClientConfig{
		STUNServerAddr: turnAddr,
		TURNServerAddr: turnAddr,
		Conn:           baseConn,
		Username:       harness.Descriptor.TURNCredentials.Username,
		Password:       harness.Descriptor.TURNCredentials.Password,
		Realm:          harness.Descriptor.TURNCredentials.Realm,
	})
	if err != nil {
		closeBaseConn(baseConn)
		t.Fatalf("create turn client: %v", err)
	}

	return client, baseConn, func() {
		client.Close()
		closeBaseConn(baseConn)
	}
}

func newHarnessTURNBaseConn(t *testing.T, harness *turnlab.Harness, turnNetwork string) (net.PacketConn, string) {
	t.Helper()

	switch turnNetwork {
	case "udp":
		baseConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
		if err != nil {
			t.Fatalf("listen turn client socket: %v", err)
		}

		return baseConn, harness.Descriptor.TURNAddress
	case "tcp":
		conn, err := net.Dial("tcp", harness.Descriptor.TURNTCPAddress)
		if err != nil {
			t.Fatalf("dial turn tcp server: %v", err)
		}

		return turn.NewSTUNConn(conn), harness.Descriptor.TURNTCPAddress
	default:
		t.Fatalf("unsupported turn network %q", turnNetwork)
		return nil, ""
	}
}

func closeBaseConn(conn net.PacketConn) {
	if conn == nil {
		return
	}
	_ = conn.Close()
}

func waitForIdleClose(t *testing.T, conn net.Conn, timeout time.Duration) {
	t.Helper()

	buf := make([]byte, 1)
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if err := conn.SetReadDeadline(time.Now().Add(50 * time.Millisecond)); err != nil {
			t.Fatalf("set deadline: %v", err)
		}
		_, err := conn.Read(buf)
		if err == nil {
			t.Fatal("expected idle connection to close")
		}
		if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
			continue
		}
		return
	}

	t.Fatalf("timed out waiting for idle close after %s", timeout)
}

func hostPart(t *testing.T, value string) string {
	t.Helper()
	host, _, err := net.SplitHostPort(value)
	if err != nil {
		t.Fatalf("SplitHostPort(%q): %v", value, err)
	}
	return host
}

func reserveUDPPort(t *testing.T) int {
	t.Helper()

	conn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("reserve udp port: %v", err)
	}
	defer conn.Close()

	addr, ok := conn.LocalAddr().(*net.UDPAddr)
	if !ok {
		t.Fatalf("unexpected udp addr type %T", conn.LocalAddr())
	}
	return addr.Port
}

func reserveTCPPort(t *testing.T) int {
	t.Helper()

	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("reserve tcp port: %v", err)
	}
	defer listener.Close()

	addr, ok := listener.Addr().(*net.TCPAddr)
	if !ok {
		t.Fatalf("unexpected tcp addr type %T", listener.Addr())
	}
	return addr.Port
}
