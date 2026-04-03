package session

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"sync"

	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

type localRouter struct {
	localConn net.PacketConn
	logger    *slog.Logger

	mu      sync.Mutex
	workers []routerWorker
	next    int
}

type routerWorker struct {
	index    int
	outbound chan transport.RelayPacket
}

func newLocalRouter(localConn net.PacketConn, logger *slog.Logger) *localRouter {
	return &localRouter{
		localConn: localConn,
		logger:    logger,
	}
}

func (r *localRouter) Run(ctx context.Context) error {
	buf := make([]byte, 1600)

	for {
		n, addr, err := r.localConn.ReadFrom(buf)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}

			return fmt.Errorf("read local datagram: %w", err)
		}

		worker, ok := r.nextWorker()
		if !ok {
			r.logger.Debug("dropping local datagram without ready workers")
			continue
		}

		packet := transport.RelayPacket{
			Payload: append([]byte(nil), buf[:n]...),
			ReplyTo: cloneSessionAddr(addr),
		}
		select {
		case worker.outbound <- packet:
		default:
			r.logger.Debug("dropping local datagram because worker queue is full", "worker", worker.index)
		}
	}
}

func (r *localRouter) Deliver(packet transport.RelayPacket) error {
	if packet.ReplyTo == nil {
		r.logger.Debug("dropping relay datagram without known local peer")
		return nil
	}

	if _, err := r.localConn.WriteTo(packet.Payload, packet.ReplyTo); err != nil {
		return fmt.Errorf("write local datagram: %w", err)
	}

	return nil
}

func (r *localRouter) SetReady(index int, outbound chan transport.RelayPacket) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.removeWorkerLocked(index)
	r.workers = append(r.workers, routerWorker{
		index:    index,
		outbound: outbound,
	})
	if r.next >= len(r.workers) {
		r.next = 0
	}
}

func (r *localRouter) Remove(index int) {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.removeWorkerLocked(index)
}

func (r *localRouter) nextWorker() (routerWorker, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if len(r.workers) == 0 {
		return routerWorker{}, false
	}

	worker := r.workers[r.next%len(r.workers)]
	r.next = (r.next + 1) % len(r.workers)
	return worker, true
}

func (r *localRouter) removeWorkerLocked(index int) {
	for i, worker := range r.workers {
		if worker.index != index {
			continue
		}

		r.workers = append(r.workers[:i], r.workers[i+1:]...)
		if len(r.workers) == 0 {
			r.next = 0
			return
		}
		if r.next >= len(r.workers) {
			r.next = 0
		}

		return
	}
}

func cloneSessionAddr(addr net.Addr) net.Addr {
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
