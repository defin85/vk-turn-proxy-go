package transport

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
)

func runOverlayForwarders(ctx context.Context, outbound <-chan overlay.Frame, inbound func(overlay.Frame) error, endpoint *overlay.Endpoint, relayConn net.Conn, logger *slog.Logger, onTraffic func(direction string, bytes int)) error {
	loopCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	stopCancel := context.AfterFunc(loopCtx, func() {
		_ = relayConn.SetDeadline(time.Now())
	})
	defer stopCancel()

	errCh := make(chan error, 2)
	go func() {
		errCh <- frameChannelToEndpoint(loopCtx, outbound, endpoint, onTraffic)
	}()
	go func() {
		errCh <- endpointToFrameHandler(loopCtx, endpoint, inbound, logger, onTraffic)
	}()

	return waitForwarderErrors(ctx, cancel, errCh, 2)
}

func runDirectDatagramForwarders(ctx context.Context, outbound <-chan overlay.Frame, inbound func(overlay.Frame) error, relayConn net.Conn, logger *slog.Logger, onTraffic func(direction string, bytes int)) error {
	loopCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	stopCancel := context.AfterFunc(loopCtx, func() {
		_ = relayConn.SetDeadline(time.Now())
	})
	defer stopCancel()

	target := &lastRouteID{}
	errCh := make(chan error, 2)
	go func() {
		errCh <- datagramChannelToRelay(loopCtx, outbound, relayConn, target, onTraffic)
	}()
	go func() {
		errCh <- relayToDatagramHandler(loopCtx, relayConn, inbound, target, logger, onTraffic)
	}()

	return waitForwarderErrors(ctx, cancel, errCh, 2)
}

func waitForwarderErrors(ctx context.Context, cancel context.CancelFunc, errCh <-chan error, count int) error {
	var errs []error
	for i := 0; i < count; i++ {
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

func frameChannelToEndpoint(ctx context.Context, outbound <-chan overlay.Frame, endpoint *overlay.Endpoint, onTraffic func(direction string, bytes int)) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case frame, ok := <-outbound:
			if !ok {
				if ctx.Err() != nil {
					return nil
				}
				return errors.New("worker outbound channel closed")
			}

			if err := endpoint.WriteFrame(frame); err != nil {
				if ctx.Err() != nil {
					return nil
				}
				return err
			}
			recordOverlayTraffic(frame, TrafficDirectionLocalToRelay, onTraffic)
		}
	}
}

func endpointToFrameHandler(ctx context.Context, endpoint *overlay.Endpoint, inbound func(overlay.Frame) error, logger *slog.Logger, onTraffic func(direction string, bytes int)) error {
	for {
		frame, err := endpoint.ReadFrame()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return fmt.Errorf("read overlay frame: %w", err)
		}

		switch frame.Kind {
		case overlay.FrameDatagram, overlay.FrameStreamData, overlay.FrameStreamClose:
		default:
			logger.Debug("dropping unexpected overlay frame from relay", "kind", frame.Kind)
			continue
		}

		if err := inbound(frame); err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		recordOverlayTraffic(frame, TrafficDirectionRelayToLocal, onTraffic)
	}
}

func datagramChannelToRelay(ctx context.Context, outbound <-chan overlay.Frame, relayConn net.Conn, target *lastRouteID, onTraffic func(direction string, bytes int)) error {
	for {
		select {
		case <-ctx.Done():
			return nil
		case frame, ok := <-outbound:
			if !ok {
				if ctx.Err() != nil {
					return nil
				}
				return errors.New("worker outbound channel closed")
			}
			if frame.Kind != overlay.FrameDatagram {
				return fmt.Errorf("plain peer path does not support overlay %s frames", frame.Kind)
			}

			target.Store(frame.RouteID)
			if _, err := relayConn.Write(frame.Payload); err != nil {
				if ctx.Err() != nil {
					return nil
				}
				return fmt.Errorf("write relay datagram: %w", err)
			}
			recordOverlayTraffic(frame, TrafficDirectionLocalToRelay, onTraffic)
		}
	}
}

func relayToDatagramHandler(ctx context.Context, relayConn net.Conn, inbound func(overlay.Frame) error, target *lastRouteID, logger *slog.Logger, onTraffic func(direction string, bytes int)) error {
	buf := make([]byte, overlay.DefaultDatagramBufferSize)
	for {
		n, err := relayConn.Read(buf)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return fmt.Errorf("read relay datagram: %w", err)
		}

		routeID, ok := target.Load()
		if !ok {
			logger.Debug("dropping relay datagram without known local route")
			continue
		}

		frame := overlay.Frame{
			Kind:    overlay.FrameDatagram,
			RouteID: routeID,
			Payload: append([]byte(nil), buf[:n]...),
		}
		if err := inbound(frame); err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		recordOverlayTraffic(frame, TrafficDirectionRelayToLocal, onTraffic)
	}
}

func recordOverlayTraffic(frame overlay.Frame, direction string, onTraffic func(direction string, bytes int)) {
	if onTraffic == nil {
		return
	}
	switch frame.Kind {
	case overlay.FrameDatagram, overlay.FrameStreamData:
		onTraffic(direction, len(frame.Payload))
	}
}

type lastRouteID struct {
	mu      sync.RWMutex
	routeID uint64
	ready   bool
}

func (p *lastRouteID) Store(routeID uint64) {
	if p == nil {
		return
	}

	p.mu.Lock()
	defer p.mu.Unlock()
	p.routeID = routeID
	p.ready = true
}

func (p *lastRouteID) Load() (uint64, bool) {
	if p == nil {
		return 0, false
	}

	p.mu.RLock()
	defer p.mu.RUnlock()
	if !p.ready {
		return 0, false
	}

	return p.routeID, true
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
