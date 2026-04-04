package transport

import (
	"context"
	"net"
	"strings"

	piontransport "github.com/pion/transport/v4"
	"github.com/pion/transport/v4/stdnet"
)

type turnNet struct {
	*stdnet.Net
	bindIP net.IP
}

func newTURNNet(bindIP net.IP) (piontransport.Net, error) {
	base, err := stdnet.NewNet()
	if err != nil {
		return nil, err
	}

	return &turnNet{
		Net:    base,
		bindIP: append(net.IP(nil), bindIP...),
	}, nil
}

func (n *turnNet) DialTCP(network string, laddr, raddr *net.TCPAddr) (piontransport.TCPConn, error) {
	if laddr == nil {
		if local, ok := localTCPAddr(n.bindIP); ok {
			laddr = local
		}
	}

	return n.Net.DialTCP(network, laddr, raddr)
}

func (n *turnNet) DialUDP(network string, laddr, raddr *net.UDPAddr) (piontransport.UDPConn, error) {
	if laddr == nil {
		if local, ok := localUDPAddr(n.bindIP); ok {
			laddr = local
		}
	}

	return n.Net.DialUDP(network, laddr, raddr)
}

func (n *turnNet) CreateDialer(dialer *net.Dialer) piontransport.Dialer {
	return &turnDialer{
		bindIP: append(net.IP(nil), n.bindIP...),
		dialer: cloneDialer(dialer),
	}
}

func (n *turnNet) CreateListenConfig(cfg *net.ListenConfig) piontransport.ListenConfig {
	return &turnListenConfig{
		bindIP: append(net.IP(nil), n.bindIP...),
		cfg:    cloneListenConfig(cfg),
	}
}

type turnDialer struct {
	bindIP net.IP
	dialer net.Dialer
}

func (d *turnDialer) Dial(network, address string) (net.Conn, error) {
	if d.dialer.LocalAddr == nil {
		d.dialer.LocalAddr = localAddrForNetwork(network, d.bindIP)
	}

	return d.dialer.Dial(network, address)
}

type turnListenConfig struct {
	bindIP net.IP
	cfg    net.ListenConfig
}

func (c *turnListenConfig) Listen(ctx context.Context, network, address string) (net.Listener, error) {
	return c.cfg.Listen(ctx, network, rewriteBindAddress(network, address, c.bindIP))
}

func (c *turnListenConfig) ListenPacket(ctx context.Context, network, address string) (net.PacketConn, error) {
	return c.cfg.ListenPacket(ctx, network, rewriteBindAddress(network, address, c.bindIP))
}

func cloneDialer(dialer *net.Dialer) net.Dialer {
	if dialer == nil {
		return net.Dialer{}
	}

	cloned := *dialer
	return cloned
}

func cloneListenConfig(cfg *net.ListenConfig) net.ListenConfig {
	if cfg == nil {
		return net.ListenConfig{}
	}

	cloned := *cfg
	return cloned
}

func rewriteBindAddress(network string, address string, bindIP net.IP) string {
	if bindIP == nil || !isSocketNetwork(network) {
		return address
	}

	host, port, err := net.SplitHostPort(address)
	if err != nil {
		return address
	}
	if host != "" {
		if ip := net.ParseIP(host); ip != nil && !ip.IsUnspecified() {
			return address
		}
	}

	return net.JoinHostPort(bindIP.String(), port)
}

func localAddrForNetwork(network string, bindIP net.IP) net.Addr {
	switch {
	case bindIP == nil:
		return nil
	case strings.HasPrefix(network, "tcp"):
		addr, ok := localTCPAddr(bindIP)
		if !ok {
			return nil
		}
		return addr
	case strings.HasPrefix(network, "udp"):
		addr, ok := localUDPAddr(bindIP)
		if !ok {
			return nil
		}
		return addr
	default:
		return nil
	}
}

func localTCPAddr(bindIP net.IP) (*net.TCPAddr, bool) {
	if bindIP == nil {
		return nil, false
	}

	return &net.TCPAddr{IP: append(net.IP(nil), bindIP...)}, true
}

func localUDPAddr(bindIP net.IP) (*net.UDPAddr, bool) {
	if bindIP == nil {
		return nil, false
	}

	return &net.UDPAddr{IP: append(net.IP(nil), bindIP...)}, true
}

func isSocketNetwork(network string) bool {
	return strings.HasPrefix(network, "tcp") || strings.HasPrefix(network, "udp")
}
