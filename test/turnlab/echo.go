package turnlab

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sync"
)

type upstreamController struct {
	conn        net.PacketConn
	mu          sync.RWMutex
	lastPeer    net.Addr
	peerUpdates chan net.Addr
}

func newUpstreamController(conn net.PacketConn) *upstreamController {
	return &upstreamController{
		conn:        conn,
		peerUpdates: make(chan net.Addr, 1),
	}
}

func (u *upstreamController) run() error {
	buf := make([]byte, 1600)

	for {
		n, addr, err := u.conn.ReadFrom(buf)
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return nil
			}

			return fmt.Errorf("read packet: %w", err)
		}

		u.storePeer(addr)

		if _, err := u.conn.WriteTo(buf[:n], addr); err != nil {
			if errors.Is(err, net.ErrClosed) {
				return nil
			}

			return fmt.Errorf("write packet: %w", err)
		}
	}
}

func (u *upstreamController) WaitPeer(ctx context.Context) (net.Addr, error) {
	if u == nil {
		return nil, errors.New("upstream controller is nil")
	}

	if addr, ok := u.LastPeer(); ok {
		return addr, nil
	}

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case addr := <-u.peerUpdates:
		return cloneAddr(addr), nil
	}
}

func (u *upstreamController) LastPeer() (net.Addr, bool) {
	if u == nil {
		return nil, false
	}

	u.mu.RLock()
	defer u.mu.RUnlock()
	if u.lastPeer == nil {
		return nil, false
	}

	return cloneAddr(u.lastPeer), true
}

func (u *upstreamController) Inject(payload []byte) error {
	if u == nil {
		return errors.New("upstream controller is nil")
	}

	addr, ok := u.LastPeer()
	if !ok {
		return errors.New("upstream peer is not known yet")
	}

	_, err := u.conn.WriteTo(payload, addr)
	if err != nil {
		if errors.Is(err, net.ErrClosed) {
			return nil
		}

		return fmt.Errorf("inject packet: %w", err)
	}

	return nil
}

func (u *upstreamController) storePeer(addr net.Addr) {
	if u == nil || addr == nil {
		return
	}

	cloned := cloneAddr(addr)

	u.mu.Lock()
	u.lastPeer = cloned
	u.mu.Unlock()

	select {
	case u.peerUpdates <- cloned:
	default:
		select {
		case <-u.peerUpdates:
		default:
		}
		select {
		case u.peerUpdates <- cloned:
		default:
		}
	}
}

func cloneAddr(addr net.Addr) net.Addr {
	switch value := addr.(type) {
	case *net.UDPAddr:
		if value == nil {
			return nil
		}

		cloned := *value
		if value.IP != nil {
			cloned.IP = append([]byte(nil), value.IP...)
		}

		return &cloned
	default:
		return addr
	}
}
