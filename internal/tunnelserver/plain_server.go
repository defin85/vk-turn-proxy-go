package tunnelserver

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"sync"
	"time"
)

type plainSession struct {
	remoteAddr  net.Addr
	upstream    net.Conn
	cancel      context.CancelFunc
	lastSeenAt  time.Time
	lastSeenAtMu sync.Mutex
}

func (s *Server) ServePlain(ctx context.Context, packetConn net.PacketConn) error {
	observer := s.observer()
	defer func() {
		if err := packetConn.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			s.logger.Warn("close plain listener", "err", err)
		}
	}()

	context.AfterFunc(ctx, func() {
		if err := packetConn.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			s.logger.Warn("close plain listener", "err", err)
		}
	})

	observer.RecordSessionStart()
	observer.Emit(ctx, slog.LevelInfo, "runtime_startup",
		"stage", "listen",
		"result", "succeeded",
		"listen", packetConn.LocalAddr().String(),
		"upstream", s.cfg.UpstreamAddr,
		"egress", s.cfg.Egress,
	)
	s.logger.Info("plain server listening", "listen", packetConn.LocalAddr().String(), "upstream", s.cfg.UpstreamAddr, "egress", s.cfg.Egress)
	defer observer.Emit(ctx, slog.LevelInfo, "runtime_stop",
		"stage", "shutdown",
		"result", "stopped",
	)

	sessions := make(map[string]*plainSession)
	var sessionsMu sync.Mutex

	closeSession := func(key string, session *plainSession) {
		sessionsMu.Lock()
		current, ok := sessions[key]
		if ok && current == session {
			delete(sessions, key)
		}
		sessionsMu.Unlock()
		_ = session.upstream.Close()
		session.cancel()
	}

	getOrCreateSession := func(remoteAddr net.Addr) (*plainSession, error) {
		key := remoteAddr.String()
		sessionsMu.Lock()
		if existing := sessions[key]; existing != nil {
			existing.touch()
			sessionsMu.Unlock()
			return existing, nil
		}
		sessionsMu.Unlock()

		upstream, err := net.Dial("udp", s.cfg.UpstreamAddr)
		if err != nil {
			return nil, fmt.Errorf("dial upstream: %w", err)
		}
		sessionCtx, cancel := context.WithCancel(ctx)
		session := &plainSession{
			remoteAddr: remoteAddr,
			upstream:   upstream,
			cancel:     cancel,
			lastSeenAt: time.Now(),
		}

		sessionsMu.Lock()
		if existing := sessions[key]; existing != nil {
			sessionsMu.Unlock()
			_ = upstream.Close()
			cancel()
			existing.touch()
			return existing, nil
		}
		sessions[key] = session
		sessionsMu.Unlock()

		go s.runPlainSession(sessionCtx, packetConn, key, session, closeSession)
		return session, nil
	}

	buf := make([]byte, 64*1024)
	for {
		if err := packetConn.SetReadDeadline(time.Now().Add(100 * time.Millisecond)); err != nil {
			return fmt.Errorf("set plain listener read deadline: %w", err)
		}
		n, remoteAddr, err := packetConn.ReadFrom(buf)
		if err != nil {
			if ctx.Err() != nil || errors.Is(err, net.ErrClosed) {
				return nil
			}
			var netErr net.Error
			if errors.As(err, &netErr) && netErr.Timeout() {
				continue
			}
			observer.RecordTransportFailure("forwarding_loop")
			return fmt.Errorf("read plain listener: %w", err)
		}

		session, err := getOrCreateSession(remoteAddr)
		if err != nil {
			observer.RecordTransportFailure("upstream_dial")
			observer.Emit(ctx, slog.LevelError, "connection_failure",
				"stage", "upstream_dial",
				"result", "failed",
				"remote", remoteAddr.String(),
				"error", err,
			)
			s.logger.Error("plain upstream session setup failed", "remote", remoteAddr.String(), "err", err)
			continue
		}

		session.touch()
		if _, err := session.upstream.Write(buf[:n]); err != nil {
			observer.RecordTransportFailure("forwarding_loop")
			s.logger.Error("plain upstream write failed", "remote", remoteAddr.String(), "err", err)
			closeSession(remoteAddr.String(), session)
			continue
		}
		observer.RecordForward("client_to_upstream", n)
	}
}

func (s *Server) runPlainSession(
	ctx context.Context,
	listener net.PacketConn,
	key string,
	session *plainSession,
	closeSession func(string, *plainSession),
) {
	defer closeSession(key, session)

	buf := make([]byte, 64*1024)
	for {
		if ctx.Err() != nil {
			return
		}
		if s.cfg.IdleTimeout > 0 && time.Since(session.lastSeen()) > s.cfg.IdleTimeout {
			return
		}
		_ = session.upstream.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
		n, err := session.upstream.Read(buf)
		if err != nil {
			var netErr net.Error
			if errors.As(err, &netErr) && netErr.Timeout() {
				continue
			}
			if ctx.Err() == nil && !errors.Is(err, net.ErrClosed) {
				s.logger.Warn("plain upstream read failed", "remote", session.remoteAddr.String(), "err", err)
			}
			return
		}
		if _, err := listener.WriteTo(buf[:n], session.remoteAddr); err != nil {
			if ctx.Err() == nil && !errors.Is(err, net.ErrClosed) {
				s.logger.Warn("plain client write failed", "remote", session.remoteAddr.String(), "err", err)
			}
			return
		}
		s.observer().RecordForward("upstream_to_client", n)
	}
}

func (s *plainSession) touch() {
	s.lastSeenAtMu.Lock()
	s.lastSeenAt = time.Now()
	s.lastSeenAtMu.Unlock()
}

func (s *plainSession) lastSeen() time.Time {
	s.lastSeenAtMu.Lock()
	defer s.lastSeenAtMu.Unlock()
	return s.lastSeenAt
}
