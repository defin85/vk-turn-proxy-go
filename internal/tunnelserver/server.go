package tunnelserver

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"sync"
	"time"

	"github.com/pion/dtls/v3"
	"github.com/pion/dtls/v3/pkg/crypto/selfsign"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
)

type Server struct {
	cfg       config.ServerConfig
	logger    *slog.Logger
	metrics   *observe.Metrics
	sessionID string
}

func New(cfg config.ServerConfig, logger *slog.Logger) (*Server, error) {
	cfg.Egress = config.AdapterKind(overlay.NormalizeAdapter(overlay.AdapterKind(cfg.Egress)))
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	if logger == nil {
		logger = slog.Default()
	}

	return &Server{
		cfg:       cfg,
		logger:    logger,
		sessionID: observe.NewSessionID(),
	}, nil
}

func (s *Server) SetMetrics(metrics *observe.Metrics) {
	if s == nil {
		return
	}

	s.metrics = metrics
}

func (s *Server) Run(ctx context.Context) error {
	listener, err := s.Listen()
	if err != nil {
		s.observer().RecordTransportFailure("listen")
		s.observer().RecordSessionFailure("listen", true)
		s.observer().Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", "listen",
			"result", "failed",
			"error", err,
		)
		return err
	}

	return s.Serve(ctx, listener)
}

func (s *Server) Listen() (net.Listener, error) {
	listenAddr, err := net.ResolveUDPAddr("udp", s.cfg.ListenAddr)
	if err != nil {
		return nil, fmt.Errorf("resolve listen addr: %w", err)
	}

	certificate, err := selfsign.GenerateSelfSigned()
	if err != nil {
		return nil, fmt.Errorf("generate self-signed certificate: %w", err)
	}

	listener, err := dtls.Listen("udp", listenAddr, &dtls.Config{
		Certificates:          []tls.Certificate{certificate},
		ExtendedMasterSecret:  dtls.RequireExtendedMasterSecret,
		CipherSuites:          []dtls.CipherSuiteID{dtls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256},
		ConnectionIDGenerator: dtls.RandomCIDGenerator(8),
	})
	if err != nil {
		return nil, fmt.Errorf("listen dtls: %w", err)
	}

	return listener, nil
}

func (s *Server) Serve(ctx context.Context, listener net.Listener) error {
	observer := s.observer()
	defer func() {
		if err := listener.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			s.logger.Warn("close listener", "err", err)
		}
	}()

	context.AfterFunc(ctx, func() {
		if err := listener.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			s.logger.Warn("close listener", "err", err)
		}
	})

	observer.RecordSessionStart()
	observer.Emit(ctx, slog.LevelInfo, "runtime_startup",
		"stage", "listen",
		"result", "succeeded",
		"listen", listener.Addr().String(),
		"upstream", s.cfg.UpstreamAddr,
		"egress", s.cfg.Egress,
	)
	s.logger.Info("server listening", "listen", listener.Addr().String(), "upstream", s.cfg.UpstreamAddr, "egress", s.cfg.Egress)
	defer observer.Emit(ctx, slog.LevelInfo, "runtime_stop",
		"stage", "shutdown",
		"result", "stopped",
	)

	var wg sync.WaitGroup
	defer wg.Wait()

	for {
		conn, acceptErr := listener.Accept()
		if acceptErr != nil {
			if ctx.Err() != nil {
				return nil
			}
			if errors.Is(acceptErr, net.ErrClosed) {
				return nil
			}

			observer.Emit(ctx, slog.LevelError, "connection_accept_failure",
				"stage", "accept",
				"result", "failed",
				"error", acceptErr,
			)
			observer.RecordTransportFailure("accept")
			s.logger.Error("accept connection", "err", acceptErr)
			continue
		}

		wg.Add(1)
		go func(conn net.Conn) {
			defer wg.Done()
			s.handleConnection(ctx, conn)
		}(conn)
	}
}

func (s *Server) handleConnection(parent context.Context, conn net.Conn) {
	observer := s.observer()
	defer func() {
		if closeErr := conn.Close(); closeErr != nil {
			s.logger.Warn("close incoming connection", "err", closeErr)
		}
	}()

	dtlsConn, ok := conn.(*dtls.Conn)
	if !ok {
		observer.RecordTransportFailure("accept")
		observer.Emit(parent, slog.LevelError, "connection_failure",
			"stage", "accept",
			"result", "failed",
		)
		s.logger.Error("unexpected incoming connection type")
		return
	}

	remoteAddr := conn.RemoteAddr().String()
	observer.Emit(parent, slog.LevelInfo, "connection_accepted",
		"stage", "accept",
		"result", "accepted",
		"remote", remoteAddr,
	)
	s.logger.Info("accepted connection", "remote", remoteAddr)

	handshakeCtx, cancelHandshake := context.WithTimeout(parent, s.cfg.HandshakeTimeout)
	defer cancelHandshake()

	if err := dtlsConn.HandshakeContext(handshakeCtx); err != nil {
		observer.RecordTransportFailure("dtls_handshake")
		observer.Emit(parent, slog.LevelError, "connection_failure",
			"stage", "dtls_handshake",
			"result", "failed",
			"remote", remoteAddr,
			"error", err,
		)
		s.logger.Error("dtls handshake failed", "remote", remoteAddr, "err", err)
		return
	}

	session, err := newServerOverlaySession(s.cfg, conn, s.logger, observer, remoteAddr)
	if err != nil {
		stage := initErrorStage(err)
		observer.RecordTransportFailure(stage)
		observer.Emit(parent, slog.LevelError, "connection_failure",
			"stage", stage,
			"result", "failed",
			"remote", remoteAddr,
			"error", err,
		)
		s.logger.Error("overlay session setup failed", "remote", remoteAddr, "stage", stage, "err", err)
		return
	}

	observer.Emit(parent, slog.LevelInfo, "connection_ready",
		"stage", "peer_setup",
		"result", "succeeded",
		"remote", remoteAddr,
		"egress", s.cfg.Egress,
	)
	s.logger.Info("overlay session ready", "remote", remoteAddr, "egress", s.cfg.Egress)

	sessionCtx, cancelSession := context.WithCancel(parent)
	defer cancelSession()
	context.AfterFunc(sessionCtx, func() {
		deadline := time.Now()
		if err := conn.SetDeadline(deadline); err != nil {
			s.logger.Warn("set incoming deadline", "remote", remoteAddr, "err", err)
		}
	})

	if err := session.Run(sessionCtx); err != nil && parent.Err() == nil && !isSessionCloseError(err) {
		observer.RecordTransportFailure("forwarding_loop")
		observer.Emit(parent, slog.LevelError, "connection_failure",
			"stage", "forwarding_loop",
			"result", "failed",
			"remote", remoteAddr,
			"error", err,
		)
		s.logger.Error("overlay session failed", "remote", remoteAddr, "err", err)
	}
	observer.Emit(parent, slog.LevelInfo, "connection_closed",
		"stage", "shutdown",
		"result", "stopped",
		"remote", remoteAddr,
	)
	s.logger.Info("connection closed", "remote", remoteAddr)
}

func isSessionCloseError(err error) bool {
	if errors.Is(err, io.EOF) || errors.Is(err, net.ErrClosed) {
		return true
	}

	var netErr net.Error
	return errors.As(err, &netErr) && netErr.Timeout()
}

func (s *Server) observer() *observe.Observer {
	return observe.NewObserver(observe.RuntimeServer, s.logger, s.metrics, observe.Metadata{
		SessionID: s.sessionID,
		Provider:  "none",
		PeerMode:  "dtls",
	})
}
