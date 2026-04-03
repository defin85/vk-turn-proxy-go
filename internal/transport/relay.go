package transport

import (
	"context"
	"fmt"
	"net"
	"time"

	"github.com/pion/dtls/v3"

	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
)

const handshakeTimeout = 5 * time.Second

func openPeerRelay(ctx context.Context, relayConn net.PacketConn, cfg ClientConfig) (net.Conn, string, error) {
	peerAddr, err := net.ResolveUDPAddr("udp", cfg.PeerAddr)
	if err != nil {
		return nil, "", runstage.Wrap(runstage.PeerSetup, fmt.Errorf("resolve peer addr: %w", err))
	}

	switch cfg.PeerMode {
	case PeerModeDTLS:
		conn, err := openDTLSRelay(ctx, relayConn, peerAddr)
		if err != nil {
			return nil, "", err
		}

		return conn, peerAddr.String(), nil
	case PeerModePlain:
		return &packetRelayConn{
			packetConn: relayConn,
			peerAddr:   cloneAddr(peerAddr),
		}, peerAddr.String(), nil
	default:
		return nil, "", runstage.Wrap(runstage.PeerSetup, fmt.Errorf("unsupported peer mode %q", cfg.PeerMode))
	}
}

func openDTLSRelay(ctx context.Context, relayConn net.PacketConn, peerAddr *net.UDPAddr) (net.Conn, error) {
	dtlsConn, err := dtls.Client(relayConn, peerAddr, &dtls.Config{
		InsecureSkipVerify:   true,
		ExtendedMasterSecret: dtls.RequireExtendedMasterSecret,
	})
	if err != nil {
		return nil, runstage.Wrap(runstage.DTLSHandshake, fmt.Errorf("create dtls client: %w", err))
	}

	handshakeCtx, cancel := context.WithTimeout(ctx, handshakeTimeout)
	defer cancel()
	if err := dtlsConn.HandshakeContext(handshakeCtx); err != nil {
		_ = dtlsConn.Close()
		return nil, runstage.Wrap(runstage.DTLSHandshake, fmt.Errorf("dtls handshake: %w", err))
	}

	return dtlsConn, nil
}

type packetRelayConn struct {
	packetConn net.PacketConn
	peerAddr   net.Addr
}

func (c *packetRelayConn) Read(p []byte) (int, error) {
	n, _, err := c.packetConn.ReadFrom(p)
	return n, err
}

func (c *packetRelayConn) Write(p []byte) (int, error) {
	return c.packetConn.WriteTo(p, c.peerAddr)
}

func (c *packetRelayConn) Close() error {
	return nil
}

func (c *packetRelayConn) LocalAddr() net.Addr {
	return c.packetConn.LocalAddr()
}

func (c *packetRelayConn) RemoteAddr() net.Addr {
	return c.peerAddr
}

func (c *packetRelayConn) SetDeadline(t time.Time) error {
	return c.packetConn.SetDeadline(t)
}

func (c *packetRelayConn) SetReadDeadline(t time.Time) error {
	return c.packetConn.SetReadDeadline(t)
}

func (c *packetRelayConn) SetWriteDeadline(t time.Time) error {
	return c.packetConn.SetWriteDeadline(t)
}
