package overlay

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

const (
	defaultTCPIngressInboundQueueSize     = 8
	defaultTCPIngressWriteTimeout         = 30 * time.Second
	defaultTCPIngressOutboundFrameTimeout = 250 * time.Millisecond
	defaultTCPIngressControlFrameTimeout  = 250 * time.Millisecond
)

type TCPIngress struct {
	listener net.Listener
	logger   *slog.Logger
	workers  workerSet

	nextStreamID         atomic.Uint64
	writeTimeout         time.Duration
	outboundFrameTimeout time.Duration

	controlFrameTimeout time.Duration

	streamMu sync.Mutex
	streams  map[uint64]*tcpLocalStream
}

type tcpLocalStream struct {
	id           uint64
	workerIndex  int
	conn         net.Conn
	outbound     chan Frame
	inbound      chan Frame
	sendSequence uint64
	recvSequence uint64
	closeOnce    sync.Once
	notifyClose  sync.Once
	done         chan struct{}
}

func NewTCPIngress(listenAddr string, logger *slog.Logger) (*TCPIngress, error) {
	if logger == nil {
		logger = slog.Default()
	}

	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return nil, fmt.Errorf("bind tcp ingress listener: %w", err)
	}

	return &TCPIngress{
		listener:             listener,
		logger:               logger,
		writeTimeout:         defaultTCPIngressWriteTimeout,
		outboundFrameTimeout: defaultTCPIngressOutboundFrameTimeout,
		controlFrameTimeout:  defaultTCPIngressControlFrameTimeout,
		streams:              make(map[uint64]*tcpLocalStream),
	}, nil
}

func (i *TCPIngress) Run(ctx context.Context) error {
	stopCancel := context.AfterFunc(ctx, func() {
		_ = i.listener.Close()
		i.closeAllStreams()
	})
	defer stopCancel()

	for {
		conn, err := i.listener.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			if errors.Is(err, net.ErrClosed) {
				return nil
			}
			return fmt.Errorf("accept tcp ingress connection: %w", err)
		}

		worker, ok := i.workers.Next()
		if !ok {
			i.logger.Debug("rejecting tcp ingress connection without ready workers")
			_ = conn.Close()
			continue
		}

		streamID := i.nextStreamID.Add(1)
		stream := &tcpLocalStream{
			id:          streamID,
			workerIndex: worker.index,
			conn:        conn,
			outbound:    worker.outbound,
			inbound:     make(chan Frame, defaultTCPIngressInboundQueueSize),
			done:        make(chan struct{}),
		}
		i.storeStream(stream)

		if err := i.sendStreamFrame(ctx, worker.outbound, Frame{
			Kind:     FrameStreamOpen,
			StreamID: streamID,
		}); err != nil {
			i.logger.Debug("rejecting tcp ingress connection because stream open could not be queued", "stream_id", streamID, "worker", worker.index, "error", err)
			i.closeStream(streamID)
			continue
		}

		go i.runStreamWriter(ctx, stream)
		go i.runStreamReader(ctx, stream)
	}
}

func (i *TCPIngress) Deliver(frame Frame) error {
	switch frame.Kind {
	case FrameStreamData:
		stream := i.lookupStream(frame.StreamID)
		if stream == nil {
			i.logger.Debug("dropping tcp overlay frame for unknown local stream", "stream_id", frame.StreamID, "kind", frame.Kind)
			return nil
		}
		if !i.queueInboundFrame(stream, frame) {
			return nil
		}
		return nil
	case FrameStreamClose:
		i.closeStream(frame.StreamID)
		return nil
	default:
		return fmt.Errorf("tcp ingress cannot deliver overlay %s frames", frame.Kind)
	}
}

func (i *TCPIngress) SetReady(index int, outbound chan Frame) {
	i.workers.SetReady(index, outbound)
}

func (i *TCPIngress) Remove(index int) {
	i.workers.Remove(index)
	i.closeWorkerStreams(index)
}

func (i *TCPIngress) Close() error {
	if i == nil || i.listener == nil {
		return nil
	}

	i.closeAllStreams()
	return i.listener.Close()
}

func (i *TCPIngress) LocalAddr() net.Addr {
	if i == nil || i.listener == nil {
		return nil
	}

	return cloneAddr(i.listener.Addr())
}

func (i *TCPIngress) runStreamReader(ctx context.Context, stream *tcpLocalStream) {
	defer i.closeStream(stream.id)

	buf := make([]byte, StreamChunkSize)
	for {
		n, err := stream.conn.Read(buf)
		if n > 0 {
			if i.lookupStream(stream.id) == nil {
				return
			}
			frame := Frame{
				Kind:     FrameStreamData,
				StreamID: stream.id,
				Sequence: stream.sendSequence,
				Payload:  append([]byte(nil), buf[:n]...),
			}
			stream.sendSequence++
			if err := i.sendStreamFrame(ctx, stream.outbound, frame); err != nil {
				if ctx.Err() == nil {
					i.logger.Debug("closing tcp ingress stream after outbound backpressure", "stream_id", stream.id, "error", err)
					i.notifyRemoteClose(stream)
				}
				return
			}
		}
		if err != nil {
			if i.lookupStream(stream.id) == nil {
				return
			}
			if err != io.EOF && !errors.Is(err, net.ErrClosed) && ctx.Err() == nil {
				i.logger.Debug("tcp ingress stream stopped", "stream_id", stream.id, "error", err)
			}
			i.notifyRemoteClose(stream)
			return
		}
	}
}

func (i *TCPIngress) runStreamWriter(ctx context.Context, stream *tcpLocalStream) {
	for {
		select {
		case <-ctx.Done():
			return
		case <-stream.done:
			return
		case frame := <-stream.inbound:
			if frame.Kind != FrameStreamData {
				continue
			}
			if frame.Sequence != stream.recvSequence {
				i.logger.Debug("closing tcp ingress stream after out-of-order frame", "stream_id", frame.StreamID, "sequence", frame.Sequence, "expected", stream.recvSequence)
				i.notifyRemoteClose(stream)
				i.closeStream(stream.id)
				return
			}
			stream.recvSequence++
			if err := stream.conn.SetWriteDeadline(time.Now().Add(i.streamWriteTimeout())); err != nil {
				i.logger.Debug("closing tcp ingress stream after local write deadline setup failure", "stream_id", frame.StreamID, "error", err)
				i.notifyRemoteClose(stream)
				i.closeStream(stream.id)
				return
			}
			if _, err := stream.conn.Write(frame.Payload); err != nil {
				i.logger.Debug("closing tcp ingress stream after local write failure", "stream_id", frame.StreamID, "error", err)
				i.notifyRemoteClose(stream)
				i.closeStream(stream.id)
				return
			}
		}
	}
}

func (i *TCPIngress) sendStreamFrame(ctx context.Context, outbound chan Frame, frame Frame) error {
	timer := time.NewTimer(i.outboundWriteTimeout())
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return ctx.Err()
	case outbound <- frame:
		return nil
	case <-timer.C:
		return fmt.Errorf("queue overlay %s frame: outbound backpressure", frame.Kind)
	}
}

func (i *TCPIngress) storeStream(stream *tcpLocalStream) {
	i.streamMu.Lock()
	defer i.streamMu.Unlock()
	i.streams[stream.id] = stream
}

func (i *TCPIngress) lookupStream(streamID uint64) *tcpLocalStream {
	i.streamMu.Lock()
	defer i.streamMu.Unlock()
	return i.streams[streamID]
}

func (i *TCPIngress) closeStream(streamID uint64) {
	i.streamMu.Lock()
	stream, ok := i.streams[streamID]
	if ok {
		delete(i.streams, streamID)
	}
	i.streamMu.Unlock()

	if !ok {
		return
	}

	stream.closeOnce.Do(func() {
		if stream.done != nil {
			close(stream.done)
		}
		_ = stream.conn.Close()
	})
}

func (i *TCPIngress) closeWorkerStreams(index int) {
	i.streamMu.Lock()
	var streamIDs []uint64
	for id, stream := range i.streams {
		if stream.workerIndex == index {
			streamIDs = append(streamIDs, id)
		}
	}
	i.streamMu.Unlock()

	for _, streamID := range streamIDs {
		i.closeStream(streamID)
	}
}

func (i *TCPIngress) queueInboundFrame(stream *tcpLocalStream, frame Frame) bool {
	select {
	case <-stream.done:
		return false
	case stream.inbound <- frame:
		return true
	default:
		i.logger.Debug("closing tcp ingress stream after inbound backpressure", "stream_id", frame.StreamID, "kind", frame.Kind)
		i.notifyRemoteClose(stream)
		i.closeStream(stream.id)
		return false
	}
}

func (i *TCPIngress) notifyRemoteClose(stream *tcpLocalStream) {
	if stream == nil || stream.outbound == nil {
		return
	}

	stream.notifyClose.Do(func() {
		timer := time.NewTimer(i.controlWriteTimeout())
		defer timer.Stop()

		select {
		case <-stream.done:
		case stream.outbound <- Frame{Kind: FrameStreamClose, StreamID: stream.id}:
		case <-timer.C:
			i.logger.Debug("dropping tcp ingress close frame after outbound backpressure", "stream_id", stream.id)
		}
	})
}

func (i *TCPIngress) streamWriteTimeout() time.Duration {
	if i == nil || i.writeTimeout <= 0 {
		return defaultTCPIngressWriteTimeout
	}
	return i.writeTimeout
}

func (i *TCPIngress) controlWriteTimeout() time.Duration {
	if i == nil || i.controlFrameTimeout <= 0 {
		return defaultTCPIngressControlFrameTimeout
	}
	return i.controlFrameTimeout
}

func (i *TCPIngress) outboundWriteTimeout() time.Duration {
	if i == nil || i.outboundFrameTimeout <= 0 {
		return defaultTCPIngressOutboundFrameTimeout
	}
	return i.outboundFrameTimeout
}

func (i *TCPIngress) closeAllStreams() {
	i.streamMu.Lock()
	var streamIDs []uint64
	for id := range i.streams {
		streamIDs = append(streamIDs, id)
	}
	i.streamMu.Unlock()

	for _, streamID := range streamIDs {
		i.closeStream(streamID)
	}
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
