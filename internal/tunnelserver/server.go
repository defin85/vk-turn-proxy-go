package tunnelserver

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"sync"
	"time"

	"github.com/pion/dtls/v3"
	"github.com/pion/dtls/v3/pkg/crypto/selfsign"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
)

type Server struct {
	cfg    config.ServerConfig
	logger *slog.Logger
}

func New(cfg config.ServerConfig, logger *slog.Logger) (*Server, error) {
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	if logger == nil {
		logger = slog.Default()
	}

	return &Server{
		cfg:    cfg,
		logger: logger,
	}, nil
}

func (s *Server) Run(ctx context.Context) error {
	listener, err := s.Listen()
	if err != nil {
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

	s.logger.Info("server listening", "listen", listener.Addr().String(), "upstream", s.cfg.UpstreamAddr)

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
	defer func() {
		if closeErr := conn.Close(); closeErr != nil {
			s.logger.Warn("close incoming connection", "err", closeErr)
		}
	}()

	dtlsConn, ok := conn.(*dtls.Conn)
	if !ok {
		s.logger.Error("unexpected incoming connection type")
		return
	}

	remoteAddr := conn.RemoteAddr().String()
	s.logger.Info("accepted connection", "remote", remoteAddr)

	handshakeCtx, cancelHandshake := context.WithTimeout(parent, s.cfg.HandshakeTimeout)
	defer cancelHandshake()

	if err := dtlsConn.HandshakeContext(handshakeCtx); err != nil {
		s.logger.Error("dtls handshake failed", "remote", remoteAddr, "err", err)
		return
	}

	upstreamConn, err := net.Dial("udp", s.cfg.UpstreamAddr)
	if err != nil {
		s.logger.Error("dial upstream", "remote", remoteAddr, "err", err)
		return
	}
	defer func() {
		if closeErr := upstreamConn.Close(); closeErr != nil {
			s.logger.Warn("close upstream connection", "remote", remoteAddr, "err", closeErr)
		}
	}()

	s.logger.Info("dtls handshake complete", "remote", remoteAddr)

	sessionCtx, cancelSession := context.WithCancel(parent)
	defer cancelSession()
	context.AfterFunc(sessionCtx, func() {
		deadline := time.Now()
		if err := conn.SetDeadline(deadline); err != nil {
			s.logger.Warn("set incoming deadline", "remote", remoteAddr, "err", err)
		}
		if err := upstreamConn.SetDeadline(deadline); err != nil {
			s.logger.Warn("set upstream deadline", "remote", remoteAddr, "err", err)
		}
	})

	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer wg.Done()
		defer cancelSession()
		s.pipeConn(sessionCtx, conn, upstreamConn, remoteAddr, "client->upstream")
	}()

	go func() {
		defer wg.Done()
		defer cancelSession()
		s.pipeConn(sessionCtx, upstreamConn, conn, remoteAddr, "upstream->client")
	}()

	wg.Wait()
	s.logger.Info("connection closed", "remote", remoteAddr)
}

func (s *Server) pipeConn(ctx context.Context, src net.Conn, dst net.Conn, remoteAddr string, direction string) {
	buffer := make([]byte, 1600)

	for {
		if ctx.Err() != nil {
			return
		}

		if err := src.SetReadDeadline(time.Now().Add(s.cfg.IdleTimeout)); err != nil {
			s.logger.Warn("set read deadline", "remote", remoteAddr, "direction", direction, "err", err)
			return
		}

		n, err := src.Read(buffer)
		if err != nil {
			if ctx.Err() == nil {
				s.logger.Debug("read loop stopped", "remote", remoteAddr, "direction", direction, "err", err)
			}
			return
		}

		if err := dst.SetWriteDeadline(time.Now().Add(s.cfg.IdleTimeout)); err != nil {
			s.logger.Warn("set write deadline", "remote", remoteAddr, "direction", direction, "err", err)
			return
		}

		if _, err := dst.Write(buffer[:n]); err != nil {
			if ctx.Err() == nil {
				s.logger.Debug("write loop stopped", "remote", remoteAddr, "direction", direction, "err", err)
			}
			return
		}
	}
}
