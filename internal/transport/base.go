package transport

import (
	"context"
	"fmt"
	"net"

	"github.com/pion/turn/v5"
)

func openTURNBaseConn(ctx context.Context, cfg ClientConfig) (net.PacketConn, error) {
	switch cfg.TURNMode {
	case TURNModeUDP:
		return listenTURNPacketConn(cfg.TURN.Address, cfg.BindIP)
	case TURNModeTCP:
		return dialTURNStream(ctx, cfg.TURN.Address, cfg.BindIP)
	default:
		return nil, fmt.Errorf("unsupported turn mode %q", cfg.TURNMode)
	}
}

func listenTURNPacketConn(turnAddr string, bindIP net.IP) (net.PacketConn, error) {
	remoteAddr, err := net.ResolveUDPAddr("udp", turnAddr)
	if err != nil {
		return nil, fmt.Errorf("resolve turn udp address %q: %w", turnAddr, err)
	}
	if err := validateIPFamily(bindIP, remoteAddr.IP); err != nil {
		return nil, err
	}

	network, localAddr := packetListenConfig(bindIP, remoteAddr.IP)
	conn, err := net.ListenPacket(network, localAddr)
	if err != nil {
		return nil, fmt.Errorf("bind turn client socket: %w", err)
	}

	return conn, nil
}

func dialTURNStream(ctx context.Context, turnAddr string, bindIP net.IP) (net.PacketConn, error) {
	remoteAddr, err := net.ResolveTCPAddr("tcp", turnAddr)
	if err != nil {
		return nil, fmt.Errorf("resolve turn tcp address %q: %w", turnAddr, err)
	}
	if err := validateIPFamily(bindIP, remoteAddr.IP); err != nil {
		return nil, err
	}

	dialer := &net.Dialer{}
	if bindIP != nil {
		dialer.LocalAddr = &net.TCPAddr{IP: append(net.IP(nil), bindIP...)}
	}

	network := "tcp"
	if remoteAddr.IP.To4() != nil {
		network = "tcp4"
	} else if remoteAddr.IP != nil {
		network = "tcp6"
	}

	conn, err := dialer.DialContext(ctx, network, remoteAddr.String())
	if err != nil {
		return nil, fmt.Errorf("dial turn server: %w", err)
	}

	return turn.NewSTUNConn(conn), nil
}

func packetListenConfig(bindIP net.IP, remoteIP net.IP) (string, string) {
	if bindIP != nil {
		if bindIP.To4() != nil {
			return "udp4", net.JoinHostPort(bindIP.String(), "0")
		}

		return "udp6", net.JoinHostPort(bindIP.String(), "0")
	}

	if remoteIP != nil && remoteIP.To4() == nil {
		return "udp6", "[::]:0"
	}

	return "udp4", "0.0.0.0:0"
}

func validateIPFamily(bindIP net.IP, remoteIP net.IP) error {
	if bindIP == nil || remoteIP == nil {
		return nil
	}

	bindIPv4 := bindIP.To4() != nil
	remoteIPv4 := remoteIP.To4() != nil
	if bindIPv4 == remoteIPv4 {
		return nil
	}

	return fmt.Errorf("bind target %s does not match turn address family %s", bindIP.String(), remoteIP.String())
}
