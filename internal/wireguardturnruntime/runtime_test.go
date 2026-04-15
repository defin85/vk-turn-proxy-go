package wireguardturnruntime

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"net"
	"net/netip"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
	"golang.org/x/crypto/curve25519"
	"golang.zx2c4.com/wireguard/conn"
	"golang.zx2c4.com/wireguard/device"
	"golang.zx2c4.com/wireguard/tun/netstack"
)

func TestDirectDatagramBindCarriesWireGuardTraffic(t *testing.T) {
	t.Parallel()

	serverPrivate, serverPublic := mustGenerateWireGuardKeyPair(t)
	clientPrivate, clientPublic := mustGenerateWireGuardKeyPair(t)

	const (
		serverListenPort = 39081
		serverTCPPort    = 8080
	)

	serverTun, serverNet, err := netstack.CreateNetTUN(
		[]netip.Addr{netip.MustParseAddr("10.10.0.1")},
		nil,
		1280,
	)
	if err != nil {
		t.Fatalf("create server netstack TUN: %v", err)
	}

	serverDevice := device.NewDevice(serverTun, conn.NewDefaultBind(), device.NewLogger(device.LogLevelVerbose, "test-server: "))
	defer serverDevice.Close()
	if err := serverDevice.IpcSet(fmt.Sprintf(
		"private_key=%s\nlisten_port=%d\npublic_key=%s\nallowed_ip=10.10.0.2/32\n",
		hex.EncodeToString(serverPrivate[:]),
		serverListenPort,
		hex.EncodeToString(clientPublic[:]),
	)); err != nil {
		t.Fatalf("configure server device: %v", err)
	}
	if err := serverDevice.Up(); err != nil {
		t.Fatalf("bring up server device: %v", err)
	}

	serverListener, err := serverNet.ListenTCPAddrPort(netip.MustParseAddrPort(fmt.Sprintf("10.10.0.1:%d", serverTCPPort)))
	if err != nil {
		t.Fatalf("listen on server netstack: %v", err)
	}
	defer serverListener.Close()
	serverErrCh := make(chan error, 1)
	go func() {
		conn, err := serverListener.Accept()
		if err != nil {
			serverErrCh <- err
			return
		}
		defer conn.Close()
		_, err = io.WriteString(conn, "ok")
		serverErrCh <- err
	}()

	packetConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen client packet conn: %v", err)
	}
	defer packetConn.Close()

	clientBind, err := newTurnDatagramBind(packetConn)
	if err != nil {
		t.Fatalf("create direct bind: %v", err)
	}
	defer clientBind.Close()

	clientTun, clientNet, err := netstack.CreateNetTUN(
		[]netip.Addr{netip.MustParseAddr("10.10.0.2")},
		nil,
		1280,
	)
	if err != nil {
		t.Fatalf("create client netstack TUN: %v", err)
	}

	clientDevice := device.NewDevice(clientTun, clientBind, device.NewLogger(device.LogLevelVerbose, "test-client: "))
	defer clientDevice.Close()

	lease := &clientcontrol.WireGuardTurnExecutionLease{
		ClientPrivateKey:    base64.StdEncoding.EncodeToString(clientPrivate[:]),
		PeerPublicKey:       base64.StdEncoding.EncodeToString(serverPublic[:]),
		PeerEndpointAddress: fmt.Sprintf("127.0.0.1:%d", serverListenPort),
		AllowedIPs:          []string{"10.10.0.1/32"},
	}
	ipcConfig, err := buildIPCConfig(lease)
	if err != nil {
		t.Fatalf("build client IPC config: %v", err)
	}
	if err := clientDevice.IpcSet(ipcConfig); err != nil {
		t.Fatalf("configure client device: %v", err)
	}
	if err := clientDevice.Up(); err != nil {
		t.Fatalf("bring up client device: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var body []byte
	for {
		if ctx.Err() != nil {
			t.Fatalf("client traffic never succeeded: %v", ctx.Err())
		}
		dialCtx, cancelDial := context.WithTimeout(ctx, 500*time.Millisecond)
		conn, err := clientNet.DialContextTCPAddrPort(dialCtx, netip.MustParseAddrPort(fmt.Sprintf("10.10.0.1:%d", serverTCPPort)))
		cancelDial()
		if err != nil {
			time.Sleep(100 * time.Millisecond)
			continue
		}
		body, err = io.ReadAll(conn)
		conn.Close()
		if err == nil {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}

	if got := string(body); got != "ok" {
		t.Fatalf("unexpected payload %q", got)
	}

	select {
	case err := <-serverErrCh:
		if err != nil {
			t.Fatalf("server write failed: %v", err)
		}
	case <-ctx.Done():
		t.Fatalf("server did not observe client connection: %v", ctx.Err())
	}
}

func mustGenerateWireGuardKeyPair(t *testing.T) ([32]byte, [32]byte) {
	t.Helper()

	var privateKey [32]byte
	if _, err := rand.Read(privateKey[:]); err != nil {
		t.Fatalf("generate private key: %v", err)
	}
	privateKey[0] &= 248
	privateKey[31] &= 127
	privateKey[31] |= 64

	publicKey, err := curve25519.X25519(privateKey[:], curve25519.Basepoint)
	if err != nil {
		t.Fatalf("derive public key: %v", err)
	}

	var publicKeyArray [32]byte
	copy(publicKeyArray[:], publicKey)
	return privateKey, publicKeyArray
}
