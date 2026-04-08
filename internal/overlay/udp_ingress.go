package overlay

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"sync"
	"time"
)

type UDPIngress struct {
	localConn net.PacketConn
	logger    *slog.Logger
	workers   workerSet

	routeMu sync.RWMutex
	routes  map[uint64]net.Addr
}

func NewUDPIngress(listenAddr string, logger *slog.Logger) (*UDPIngress, error) {
	if logger == nil {
		logger = slog.Default()
	}

	localConn, err := net.ListenPacket("udp", listenAddr)
	if err != nil {
		return nil, fmt.Errorf("bind udp ingress listener: %w", err)
	}

	return &UDPIngress{
		localConn: localConn,
		logger:    logger,
		routes:    make(map[uint64]net.Addr),
	}, nil
}

func (i *UDPIngress) Run(ctx context.Context) error {
	stopCancel := context.AfterFunc(ctx, func() {
		_ = i.localConn.SetDeadline(time.Now())
	})
	defer stopCancel()

	buf := make([]byte, DefaultDatagramBufferSize)
	for {
		n, addr, err := i.localConn.ReadFrom(buf)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return fmt.Errorf("read udp ingress datagram: %w", err)
		}

		worker, ok := i.workers.Next()
		if !ok {
			i.logger.Debug("dropping udp ingress datagram without ready workers")
			continue
		}

		routeID := routeIDForWorker(worker.index)
		i.storeRoute(routeID, addr)

		frame := Frame{
			Kind:    FrameDatagram,
			RouteID: routeID,
			Payload: append([]byte(nil), buf[:n]...),
		}
		select {
		case worker.outbound <- frame:
		default:
			i.logger.Debug("dropping udp ingress datagram because worker queue is full", "worker", worker.index)
		}
	}
}

func (i *UDPIngress) Deliver(frame Frame) error {
	if frame.Kind != FrameDatagram {
		return fmt.Errorf("udp ingress cannot deliver overlay %s frames", frame.Kind)
	}

	addr, ok := i.loadRoute(frame.RouteID)
	if !ok {
		i.logger.Debug("dropping udp ingress datagram without known local route", "route_id", frame.RouteID)
		return nil
	}

	if _, err := i.localConn.WriteTo(frame.Payload, addr); err != nil {
		return fmt.Errorf("write udp ingress datagram: %w", err)
	}

	return nil
}

func (i *UDPIngress) SetReady(index int, outbound chan Frame) {
	i.workers.SetReady(index, outbound)
}

func (i *UDPIngress) Remove(index int) {
	i.workers.Remove(index)
	i.deleteRoute(routeIDForWorker(index))
}

func (i *UDPIngress) Close() error {
	if i == nil || i.localConn == nil {
		return nil
	}

	return i.localConn.Close()
}

func (i *UDPIngress) LocalAddr() net.Addr {
	if i == nil || i.localConn == nil {
		return nil
	}

	return cloneAddr(i.localConn.LocalAddr())
}

func (i *UDPIngress) storeRoute(routeID uint64, addr net.Addr) {
	i.routeMu.Lock()
	defer i.routeMu.Unlock()
	i.routes[routeID] = cloneAddr(addr)
}

func (i *UDPIngress) loadRoute(routeID uint64) (net.Addr, bool) {
	i.routeMu.RLock()
	defer i.routeMu.RUnlock()

	addr, ok := i.routes[routeID]
	if !ok {
		return nil, false
	}

	return cloneAddr(addr), true
}

func (i *UDPIngress) deleteRoute(routeID uint64) {
	i.routeMu.Lock()
	defer i.routeMu.Unlock()
	delete(i.routes, routeID)
}
