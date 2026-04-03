package transport

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"sync"
	"time"
)

func runPacketConnForwarders(ctx context.Context, localConn net.PacketConn, relayConn net.Conn, logger *slog.Logger, interruptLocal bool, onTraffic func(direction string, bytes int)) error {
	loopCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	stopCancel := context.AfterFunc(loopCtx, func() {
		now := time.Now()
		if interruptLocal {
			_ = localConn.SetDeadline(now)
		}
		_ = relayConn.SetDeadline(now)
	})
	defer stopCancel()

	replyTarget := &lastLocalPeer{}
	errCh := make(chan error, 2)

	go func() {
		errCh <- packetConnToRelay(loopCtx, localConn, relayConn, replyTarget, onTraffic)
	}()
	go func() {
		errCh <- relayToPacketConn(loopCtx, relayConn, localConn, replyTarget, logger, onTraffic)
	}()

	var errs []error
	for i := 0; i < 2; i++ {
		err := <-errCh
		if err != nil {
			errs = append(errs, err)
			cancel()
		}
	}

	if ctx.Err() != nil {
		return nil
	}

	return errors.Join(errs...)
}

func runChannelForwarders(ctx context.Context, outbound <-chan RelayPacket, inbound func(RelayPacket) error, relayConn net.Conn, logger *slog.Logger, onTraffic func(direction string, bytes int)) error {
	loopCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	stopCancel := context.AfterFunc(loopCtx, func() {
		_ = relayConn.SetDeadline(time.Now())
	})
	defer stopCancel()

	replyTarget := &lastLocalPeer{}
	errCh := make(chan error, 2)

	go func() {
		errCh <- channelToRelay(loopCtx, outbound, relayConn, replyTarget, onTraffic)
	}()
	go func() {
		errCh <- relayToHandler(loopCtx, relayConn, inbound, replyTarget, logger, onTraffic)
	}()

	var errs []error
	for i := 0; i < 2; i++ {
		err := <-errCh
		if err != nil {
			errs = append(errs, err)
			cancel()
		}
	}

	if ctx.Err() != nil {
		return nil
	}

	return errors.Join(errs...)
}

func packetConnToRelay(ctx context.Context, localConn net.PacketConn, relayConn net.Conn, target *lastLocalPeer, onTraffic func(direction string, bytes int)) error {
	buf := make([]byte, 1600)

	for {
		n, addr, err := localConn.ReadFrom(buf)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}

			return fmt.Errorf("read local datagram: %w", err)
		}

		target.Store(addr)
		if _, err := relayConn.Write(buf[:n]); err != nil {
			if ctx.Err() != nil {
				return nil
			}

			return fmt.Errorf("write relay datagram: %w", err)
		}
		if onTraffic != nil {
			onTraffic(TrafficDirectionLocalToRelay, n)
		}
	}
}

func relayToPacketConn(ctx context.Context, relayConn net.Conn, localConn net.PacketConn, target *lastLocalPeer, logger *slog.Logger, onTraffic func(direction string, bytes int)) error {
	return relayToHandler(ctx, relayConn, func(packet RelayPacket) error {
		_, err := localConn.WriteTo(packet.Payload, packet.ReplyTo)
		if err != nil {
			return fmt.Errorf("write local datagram: %w", err)
		}
		if onTraffic != nil {
			onTraffic(TrafficDirectionRelayToLocal, len(packet.Payload))
		}

		return nil
	}, target, logger, nil)
}

func channelToRelay(ctx context.Context, outbound <-chan RelayPacket, relayConn net.Conn, target *lastLocalPeer, onTraffic func(direction string, bytes int)) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case packet, ok := <-outbound:
			if !ok {
				if ctx.Err() != nil {
					return nil
				}

				return errors.New("worker outbound channel closed")
			}

			target.Store(packet.ReplyTo)
			if _, err := relayConn.Write(packet.Payload); err != nil {
				if ctx.Err() != nil {
					return nil
				}

				return fmt.Errorf("write relay datagram: %w", err)
			}
			if onTraffic != nil {
				onTraffic(TrafficDirectionLocalToRelay, len(packet.Payload))
			}
		}
	}
}

func relayToHandler(ctx context.Context, relayConn net.Conn, inbound func(RelayPacket) error, target *lastLocalPeer, logger *slog.Logger, onTraffic func(direction string, bytes int)) error {
	buf := make([]byte, 1600)

	for {
		n, err := relayConn.Read(buf)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}

			return fmt.Errorf("read relay datagram: %w", err)
		}

		addr, ok := target.Load()
		if !ok {
			logger.Debug("dropping relay datagram without known local peer")
			continue
		}

		packet := RelayPacket{
			Payload: append([]byte(nil), buf[:n]...),
			ReplyTo: addr,
		}
		if err := inbound(packet); err != nil {
			if ctx.Err() != nil {
				return nil
			}

			return err
		}
		if onTraffic != nil {
			onTraffic(TrafficDirectionRelayToLocal, len(packet.Payload))
		}
	}
}

type lastLocalPeer struct {
	mu   sync.RWMutex
	addr net.Addr
}

func (p *lastLocalPeer) Store(addr net.Addr) {
	if p == nil || addr == nil {
		return
	}

	p.mu.Lock()
	defer p.mu.Unlock()
	p.addr = cloneAddr(addr)
}

func (p *lastLocalPeer) Load() (net.Addr, bool) {
	if p == nil {
		return nil, false
	}

	p.mu.RLock()
	defer p.mu.RUnlock()
	if p.addr == nil {
		return nil, false
	}

	return cloneAddr(p.addr), true
}

func cloneAddr(addr net.Addr) net.Addr {
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

func closePacketConn(conn net.PacketConn) {
	if conn == nil {
		return
	}
	_ = conn.Close()
}

func closeConn(conn net.Conn) {
	if conn == nil {
		return
	}
	_ = conn.Close()
}
