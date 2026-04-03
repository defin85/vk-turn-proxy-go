package turnlab_test

import (
	"bytes"
	"context"
	"errors"
	"net"
	"strings"
	"testing"
	"time"

	"github.com/pion/dtls/v3"
	"github.com/pion/turn/v4"

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
	if harness.Descriptor.PeerAddress == "" {
		t.Fatal("peer address is empty")
	}
	if harness.Descriptor.UpstreamAddress == "" {
		t.Fatal("upstream address is empty")
	}
	if link := harness.GenericTurnLink(); !strings.HasPrefix(link, "generic-turn://") {
		t.Fatalf("unexpected generic-turn link: %q", link)
	}

	dtlsConn, _, cleanup := dialHarnessDTLS(t, harness)
	t.Cleanup(cleanup)

	payload := []byte("turn-lab-smoke")
	if err := dtlsConn.SetDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatalf("set deadline: %v", err)
	}
	if _, err := dtlsConn.Write(payload); err != nil {
		t.Fatalf("write payload: %v", err)
	}

	buf := make([]byte, 64)
	n, err := dtlsConn.Read(buf)
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
	_, relayAddr, cleanup := dialHarnessDTLS(t, harness)
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

func dialHarnessDTLS(t *testing.T, harness *turnlab.Harness) (*dtls.Conn, string, func()) {
	t.Helper()

	baseConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen turn client socket: %v", err)
	}

	client, err := turn.NewClient(&turn.ClientConfig{
		STUNServerAddr: harness.Descriptor.TURNAddress,
		TURNServerAddr: harness.Descriptor.TURNAddress,
		Conn:           baseConn,
		Username:       harness.Descriptor.TURNCredentials.Username,
		Password:       harness.Descriptor.TURNCredentials.Password,
		Realm:          harness.Descriptor.TURNCredentials.Realm,
	})
	if err != nil {
		_ = baseConn.Close()
		t.Fatalf("create turn client: %v", err)
	}

	cleanup := func() {
		client.Close()
		_ = baseConn.Close()
	}

	if err := client.Listen(); err != nil {
		cleanup()
		t.Fatalf("listen turn client: %v", err)
	}

	relayConn, err := client.Allocate()
	if err != nil {
		cleanup()
		t.Fatalf("allocate relay: %v", err)
	}

	cleanup = func() {
		_ = relayConn.Close()
		client.Close()
		_ = baseConn.Close()
	}

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

	return dtlsConn, relayConn.LocalAddr().String(), func() {
		_ = dtlsConn.Close()
		cleanup()
	}
}
