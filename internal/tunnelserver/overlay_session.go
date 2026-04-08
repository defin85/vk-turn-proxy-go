package tunnelserver

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
)

type sessionInitError struct {
	stage string
	err   error
}

func (e *sessionInitError) Error() string {
	if e == nil || e.err == nil {
		return ""
	}
	return e.err.Error()
}

func (e *sessionInitError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.err
}

func initErrorStage(err error) string {
	var target *sessionInitError
	if errors.As(err, &target) && target.stage != "" {
		return target.stage
	}
	return "peer_setup"
}

type serverOverlaySession struct {
	conn        net.Conn
	endpoint    *overlay.Endpoint
	egress      egressAdapter
	logger      *slog.Logger
	observer    *observe.Observer
	remoteAddr  string
	idleTimeout time.Duration
}

type egressAdapter interface {
	Run(context.Context) error
	HandleFrame(context.Context, overlay.Frame) error
	Close() error
}

const (
	defaultTCPEgressInboundQueueSize    = 8
	defaultTCPEgressControlFrameTimeout = 250 * time.Millisecond
)

func newServerOverlaySession(cfg config.ServerConfig, conn net.Conn, logger *slog.Logger, observer *observe.Observer, remoteAddr string) (*serverOverlaySession, error) {
	endpoint := overlay.NewEndpoint(conn, logger)
	if err := conn.SetDeadline(time.Now().Add(cfg.HandshakeTimeout)); err != nil {
		return nil, &sessionInitError{stage: "peer_setup", err: fmt.Errorf("set overlay handshake deadline: %w", err)}
	}
	defer func() {
		_ = conn.SetDeadline(time.Time{})
	}()

	frame, err := endpoint.ReadFrame()
	if err != nil {
		return nil, &sessionInitError{stage: "peer_setup", err: fmt.Errorf("read overlay hello: %w", err)}
	}
	if frame.Kind != overlay.FrameHello {
		return nil, &sessionInitError{stage: "peer_setup", err: fmt.Errorf("expected overlay hello frame, got %s", frame.Kind)}
	}

	ingress := overlay.NormalizeAdapter(frame.Adapter)
	egress := overlay.NormalizeAdapter(overlay.AdapterKind(cfg.Egress))
	if !overlay.SupportedPair(ingress, egress) {
		reason := fmt.Sprintf("unsupported overlay adapter pair %s -> %s", ingress, egress)
		_ = endpoint.WriteFrame(overlay.Frame{Kind: overlay.FrameHelloReject, Reason: reason})
		return nil, &sessionInitError{stage: "peer_setup", err: errors.New(reason)}
	}

	adapter, err := newEgressAdapter(cfg, endpoint, logger, observer, remoteAddr)
	if err != nil {
		_ = endpoint.WriteFrame(overlay.Frame{Kind: overlay.FrameHelloReject, Reason: err.Error()})
		return nil, err
	}
	if err := endpoint.WriteFrame(overlay.Frame{
		Kind:    overlay.FrameHelloAck,
		Adapter: egress,
	}); err != nil {
		_ = adapter.Close()
		return nil, &sessionInitError{stage: "peer_setup", err: fmt.Errorf("write overlay hello ack: %w", err)}
	}

	return &serverOverlaySession{
		conn:        conn,
		endpoint:    endpoint,
		egress:      adapter,
		logger:      logger,
		observer:    observer,
		remoteAddr:  remoteAddr,
		idleTimeout: cfg.IdleTimeout,
	}, nil
}

func (s *serverOverlaySession) Run(ctx context.Context) error {
	loopCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	stopCancel := context.AfterFunc(loopCtx, func() {
		_ = s.egress.Close()
		_ = s.conn.Close()
	})
	defer stopCancel()

	errCh := make(chan error, 2)
	go func() {
		errCh <- s.egress.Run(loopCtx)
	}()
	go func() {
		errCh <- s.runClientFrames(loopCtx)
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

func (s *serverOverlaySession) runClientFrames(ctx context.Context) error {
	for {
		if err := s.conn.SetReadDeadline(time.Now().Add(s.idleTimeout)); err != nil {
			return fmt.Errorf("set overlay read deadline: %w", err)
		}
		frame, err := s.endpoint.ReadFrame()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return fmt.Errorf("read overlay frame: %w", err)
		}

		switch frame.Kind {
		case overlay.FrameDatagram, overlay.FrameStreamOpen, overlay.FrameStreamData, overlay.FrameStreamClose:
		default:
			s.logger.Debug("dropping unexpected overlay frame from client", "remote", s.remoteAddr, "kind", frame.Kind)
			continue
		}

		if err := s.egress.HandleFrame(ctx, frame); err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
	}
}

func newEgressAdapter(cfg config.ServerConfig, endpoint overlay.FrameWriter, logger *slog.Logger, observer *observe.Observer, remoteAddr string) (egressAdapter, error) {
	switch overlay.NormalizeAdapter(overlay.AdapterKind(cfg.Egress)) {
	case overlay.AdapterUDP:
		return newUDPEgressAdapter(cfg, endpoint, logger, observer, remoteAddr)
	case overlay.AdapterTCP:
		return newTCPEgressAdapter(cfg, endpoint, logger, observer, remoteAddr), nil
	default:
		return nil, &sessionInitError{stage: "peer_setup", err: fmt.Errorf("unsupported server egress adapter %q", cfg.Egress)}
	}
}

type udpEgressAdapter struct {
	upstreamConn net.Conn
	endpoint     overlay.FrameWriter
	logger       *slog.Logger
	observer     *observe.Observer
	remoteAddr   string
	routeMu      sync.RWMutex
	routeID      uint64
	routeReady   bool
}

func newUDPEgressAdapter(cfg config.ServerConfig, endpoint overlay.FrameWriter, logger *slog.Logger, observer *observe.Observer, remoteAddr string) (*udpEgressAdapter, error) {
	upstreamConn, err := net.Dial("udp", cfg.UpstreamAddr)
	if err != nil {
		return nil, &sessionInitError{stage: "upstream_dial", err: fmt.Errorf("dial upstream: %w", err)}
	}

	return &udpEgressAdapter{
		upstreamConn: upstreamConn,
		endpoint:     endpoint,
		logger:       logger,
		observer:     observer,
		remoteAddr:   remoteAddr,
	}, nil
}

func (a *udpEgressAdapter) Run(ctx context.Context) error {
	buf := make([]byte, overlay.DefaultDatagramBufferSize)
	for {
		_ = a.upstreamConn.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
		n, err := a.upstreamConn.Read(buf)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			var netErr net.Error
			if errors.As(err, &netErr) && netErr.Timeout() {
				continue
			}
			return fmt.Errorf("read udp upstream: %w", err)
		}

		routeID, ok := a.loadRoute()
		if !ok {
			a.logger.Debug("dropping upstream datagram without known overlay route", "remote", a.remoteAddr)
			continue
		}

		frame := overlay.Frame{
			Kind:    overlay.FrameDatagram,
			RouteID: routeID,
			Payload: append([]byte(nil), buf[:n]...),
		}
		if err := a.endpoint.WriteFrame(frame); err != nil {
			return err
		}
		a.observer.RecordForward("upstream_to_client", len(frame.Payload))
	}
}

func (a *udpEgressAdapter) HandleFrame(_ context.Context, frame overlay.Frame) error {
	if frame.Kind != overlay.FrameDatagram {
		return fmt.Errorf("udp egress cannot handle overlay %s frames", frame.Kind)
	}

	a.storeRoute(frame.RouteID)
	if _, err := a.upstreamConn.Write(frame.Payload); err != nil {
		return fmt.Errorf("write udp upstream: %w", err)
	}
	a.observer.RecordForward("client_to_upstream", len(frame.Payload))
	return nil
}

func (a *udpEgressAdapter) Close() error {
	if a == nil || a.upstreamConn == nil {
		return nil
	}
	return a.upstreamConn.Close()
}

func (a *udpEgressAdapter) storeRoute(routeID uint64) {
	a.routeMu.Lock()
	defer a.routeMu.Unlock()
	a.routeID = routeID
	a.routeReady = true
}

func (a *udpEgressAdapter) loadRoute() (uint64, bool) {
	a.routeMu.RLock()
	defer a.routeMu.RUnlock()
	if !a.routeReady {
		return 0, false
	}
	return a.routeID, true
}

type tcpEgressAdapter struct {
	cfg                 config.ServerConfig
	endpoint            overlay.FrameWriter
	logger              *slog.Logger
	observer            *observe.Observer
	remoteAddr          string
	dialContext         func(context.Context, string, string) (net.Conn, error)
	controlFrameTimeout time.Duration

	streamMu sync.Mutex
	streams  map[uint64]*tcpUpstreamStream
}

type tcpUpstreamStream struct {
	id           uint64
	cancel       context.CancelFunc
	conn         net.Conn
	connMu       sync.Mutex
	inbound      chan overlay.Frame
	sendSequence uint64
	recvSequence uint64
	closeOnce    sync.Once
	notifyClose  sync.Once
	done         chan struct{}
}

func newTCPEgressAdapter(cfg config.ServerConfig, endpoint overlay.FrameWriter, logger *slog.Logger, observer *observe.Observer, remoteAddr string) *tcpEgressAdapter {
	adapter := &tcpEgressAdapter{
		cfg:                 cfg,
		endpoint:            endpoint,
		logger:              logger,
		observer:            observer,
		remoteAddr:          remoteAddr,
		controlFrameTimeout: defaultTCPEgressControlFrameTimeout,
		streams:             make(map[uint64]*tcpUpstreamStream),
	}
	adapter.dialContext = (&net.Dialer{}).DialContext
	return adapter
}

func (a *tcpEgressAdapter) Run(ctx context.Context) error {
	<-ctx.Done()
	return nil
}

func (a *tcpEgressAdapter) HandleFrame(ctx context.Context, frame overlay.Frame) error {
	switch frame.Kind {
	case overlay.FrameStreamOpen:
		return a.openStream(ctx, frame.StreamID)
	case overlay.FrameStreamData:
		return a.writeStream(frame)
	case overlay.FrameStreamClose:
		a.closeStream(frame.StreamID, false)
		return nil
	default:
		return fmt.Errorf("tcp egress cannot handle overlay %s frames", frame.Kind)
	}
}

func (a *tcpEgressAdapter) Close() error {
	a.streamMu.Lock()
	var ids []uint64
	for id := range a.streams {
		ids = append(ids, id)
	}
	a.streamMu.Unlock()

	for _, id := range ids {
		a.closeStream(id, false)
	}
	return nil
}

func (a *tcpEgressAdapter) openStream(ctx context.Context, streamID uint64) error {
	streamCtx, cancel := context.WithCancel(ctx)
	stream := &tcpUpstreamStream{
		id:      streamID,
		cancel:  cancel,
		inbound: make(chan overlay.Frame, defaultTCPEgressInboundQueueSize),
		done:    make(chan struct{}),
	}
	if !a.storeStream(stream) {
		cancel()
		return fmt.Errorf("overlay stream %d is already open", streamID)
	}

	go a.runStream(streamCtx, stream)
	return nil
}

func (a *tcpEgressAdapter) writeStream(frame overlay.Frame) error {
	stream := a.lookupStream(frame.StreamID)
	if stream == nil {
		a.logger.Debug("dropping tcp overlay frame for unknown upstream stream", "remote", a.remoteAddr, "stream_id", frame.StreamID)
		return nil
	}
	if !a.queueInboundFrame(stream, frame) {
		return nil
	}
	return nil
}

func (a *tcpEgressAdapter) runStream(ctx context.Context, stream *tcpUpstreamStream) {
	defer a.closeStream(stream.id, true)

	dialCtx := ctx
	cancelDial := func() {}
	if timeout := a.dialTimeout(); timeout > 0 {
		dialCtx, cancelDial = context.WithTimeout(ctx, timeout)
	}
	upstreamConn, err := a.dialContext(dialCtx, "tcp", a.cfg.UpstreamAddr)
	cancelDial()
	if err != nil {
		if ctx.Err() == nil {
			a.observer.RecordTransportFailure("upstream_dial")
			a.logger.Debug("tcp upstream dial failed", "remote", a.remoteAddr, "stream_id", stream.id, "error", err)
		}
		return
	}
	stream.setConn(upstreamConn)

	loopCtx, cancelLoop := context.WithCancel(ctx)
	defer cancelLoop()

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		a.runStreamReader(loopCtx, stream)
		cancelLoop()
	}()
	go func() {
		defer wg.Done()
		a.runStreamWriter(loopCtx, stream)
		cancelLoop()
	}()
	wg.Wait()
}

func (a *tcpEgressAdapter) storeStream(stream *tcpUpstreamStream) bool {
	a.streamMu.Lock()
	defer a.streamMu.Unlock()
	if _, ok := a.streams[stream.id]; ok {
		return false
	}
	a.streams[stream.id] = stream
	return true
}

func (a *tcpEgressAdapter) lookupStream(streamID uint64) *tcpUpstreamStream {
	a.streamMu.Lock()
	defer a.streamMu.Unlock()
	return a.streams[streamID]
}

func (a *tcpEgressAdapter) closeStream(streamID uint64, notify bool) {
	a.streamMu.Lock()
	stream, ok := a.streams[streamID]
	if ok {
		delete(a.streams, streamID)
	}
	a.streamMu.Unlock()

	if !ok {
		return
	}

	stream.closeOnce.Do(func() {
		if stream.cancel != nil {
			stream.cancel()
		}
		if stream.done != nil {
			close(stream.done)
		}
		stream.closeConn()
		if notify {
			a.notifyRemoteClose(stream)
		}
	})
}

func (a *tcpEgressAdapter) queueInboundFrame(stream *tcpUpstreamStream, frame overlay.Frame) bool {
	select {
	case <-stream.done:
		return false
	case stream.inbound <- frame:
		return true
	default:
		a.logger.Debug("closing tcp upstream stream after inbound backpressure", "remote", a.remoteAddr, "stream_id", frame.StreamID, "kind", frame.Kind)
		go a.closeStream(stream.id, true)
		return false
	}
}

func (a *tcpEgressAdapter) runStreamReader(ctx context.Context, stream *tcpUpstreamStream) {
	conn := stream.loadConn()
	if conn == nil {
		return
	}

	buf := make([]byte, overlay.StreamChunkSize)
	for {
		if err := conn.SetReadDeadline(time.Now().Add(a.cfg.IdleTimeout)); err != nil {
			return
		}
		n, err := conn.Read(buf)
		if n > 0 {
			frame := overlay.Frame{
				Kind:     overlay.FrameStreamData,
				StreamID: stream.id,
				Sequence: stream.sendSequence,
				Payload:  append([]byte(nil), buf[:n]...),
			}
			stream.sendSequence++
			if err := a.endpoint.WriteFrame(frame); err != nil {
				return
			}
			a.observer.RecordForward("upstream_to_client", len(frame.Payload))
		}
		if err != nil {
			if err != io.EOF && ctx.Err() == nil && !errors.Is(err, net.ErrClosed) {
				a.logger.Debug("tcp upstream stream stopped", "remote", a.remoteAddr, "stream_id", stream.id, "error", err)
			}
			return
		}
		if ctx.Err() != nil {
			return
		}
	}
}

func (a *tcpEgressAdapter) runStreamWriter(ctx context.Context, stream *tcpUpstreamStream) {
	conn := stream.loadConn()
	if conn == nil {
		return
	}

	for {
		select {
		case <-ctx.Done():
			return
		case <-stream.done:
			return
		case frame := <-stream.inbound:
			if frame.Kind != overlay.FrameStreamData {
				continue
			}
			if frame.Sequence != stream.recvSequence {
				a.logger.Debug("closing tcp upstream stream after out-of-order frame", "remote", a.remoteAddr, "stream_id", frame.StreamID, "sequence", frame.Sequence, "expected", stream.recvSequence)
				return
			}
			stream.recvSequence++
			if err := conn.SetWriteDeadline(time.Now().Add(a.cfg.IdleTimeout)); err != nil {
				return
			}
			if _, err := conn.Write(frame.Payload); err != nil {
				return
			}
			a.observer.RecordForward("client_to_upstream", len(frame.Payload))
		}
	}
}

func (a *tcpEgressAdapter) notifyRemoteClose(stream *tcpUpstreamStream) {
	if stream == nil {
		return
	}

	stream.notifyClose.Do(func() {
		frame := overlay.Frame{
			Kind:     overlay.FrameStreamClose,
			StreamID: stream.id,
		}
		if writer, ok := a.endpoint.(interface {
			WriteFrameWithDeadline(overlay.Frame, time.Duration) error
		}); ok {
			if err := writer.WriteFrameWithDeadline(frame, a.controlWriteTimeout()); err != nil {
				a.logger.Debug("tcp upstream close frame send failed", "remote", a.remoteAddr, "stream_id", stream.id, "error", err)
			}
			return
		}
		if err := a.endpoint.WriteFrame(frame); err != nil {
			a.logger.Debug("tcp upstream close frame send failed", "remote", a.remoteAddr, "stream_id", stream.id, "error", err)
		}
	})
}

func (a *tcpEgressAdapter) dialTimeout() time.Duration {
	if a == nil || a.cfg.HandshakeTimeout <= 0 {
		return 30 * time.Second
	}
	return a.cfg.HandshakeTimeout
}

func (a *tcpEgressAdapter) controlWriteTimeout() time.Duration {
	if a == nil || a.controlFrameTimeout <= 0 {
		return defaultTCPEgressControlFrameTimeout
	}
	return a.controlFrameTimeout
}

func (s *tcpUpstreamStream) setConn(conn net.Conn) {
	s.connMu.Lock()
	defer s.connMu.Unlock()
	s.conn = conn
}

func (s *tcpUpstreamStream) loadConn() net.Conn {
	s.connMu.Lock()
	defer s.connMu.Unlock()
	return s.conn
}

func (s *tcpUpstreamStream) closeConn() {
	s.connMu.Lock()
	defer s.connMu.Unlock()
	if s.conn == nil {
		return
	}
	_ = s.conn.Close()
	s.conn = nil
}
