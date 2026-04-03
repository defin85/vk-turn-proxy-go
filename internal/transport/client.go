package transport

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"sync"
	"time"

	"github.com/pion/dtls/v3"
	"github.com/pion/turn/v4"

	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
)

const handshakeTimeout = 5 * time.Second

type TURNCredentials struct {
	Address  string
	Username string
	Password string
}

type ClientConfig struct {
	ListenAddr string
	PeerAddr   string
	TURN       TURNCredentials
	Logger     *slog.Logger
	Hooks      ClientHooks
}

type ClientHooks struct {
	OnLocalBind     func(net.Addr)
	OnTURNBaseBind  func(net.Addr)
	OnRelayAllocate func(net.Addr)
}

type clientRunner struct {
	cfg ClientConfig
}

func NewClientRunner(cfg ClientConfig) Runner {
	return &clientRunner{cfg: cfg}
}

func (r *clientRunner) Run(ctx context.Context) error {
	if ctx == nil {
		ctx = context.Background()
	}

	logger := r.cfg.Logger
	if logger == nil {
		logger = slog.Default()
	}

	localConn, err := net.ListenPacket("udp", r.cfg.ListenAddr)
	if err != nil {
		return runstage.Wrap(runstage.LocalBind, fmt.Errorf("bind local listener: %w", err))
	}
	defer closePacketConn(localConn)
	if r.cfg.Hooks.OnLocalBind != nil {
		r.cfg.Hooks.OnLocalBind(cloneAddr(localConn.LocalAddr()))
	}

	baseConn, err := listenTURNBaseSocket(r.cfg.TURN.Address)
	if err != nil {
		return runstage.Wrap(runstage.TURNDial, err)
	}
	defer closePacketConn(baseConn)
	if r.cfg.Hooks.OnTURNBaseBind != nil {
		r.cfg.Hooks.OnTURNBaseBind(cloneAddr(baseConn.LocalAddr()))
	}

	client, err := turn.NewClient(&turn.ClientConfig{
		STUNServerAddr: r.cfg.TURN.Address,
		TURNServerAddr: r.cfg.TURN.Address,
		Conn:           baseConn,
		Username:       r.cfg.TURN.Username,
		Password:       r.cfg.TURN.Password,
	})
	if err != nil {
		return runstage.Wrap(runstage.TURNDial, fmt.Errorf("create turn client: %w", err))
	}
	defer client.Close()

	if err := client.Listen(); err != nil {
		return runstage.Wrap(runstage.TURNDial, fmt.Errorf("listen turn client: %w", err))
	}

	relayConn, err := client.Allocate()
	if err != nil {
		return runstage.Wrap(runstage.TURNAllocate, fmt.Errorf("allocate turn relay: %w", err))
	}
	defer closePacketConn(relayConn)
	if r.cfg.Hooks.OnRelayAllocate != nil {
		r.cfg.Hooks.OnRelayAllocate(cloneAddr(relayConn.LocalAddr()))
	}

	peerAddr, err := net.ResolveUDPAddr("udp", r.cfg.PeerAddr)
	if err != nil {
		return runstage.Wrap(runstage.DTLSHandshake, fmt.Errorf("resolve peer addr: %w", err))
	}

	dtlsConn, err := dtls.Client(relayConn, peerAddr, &dtls.Config{
		InsecureSkipVerify:   true,
		ExtendedMasterSecret: dtls.RequireExtendedMasterSecret,
	})
	if err != nil {
		return runstage.Wrap(runstage.DTLSHandshake, fmt.Errorf("create dtls client: %w", err))
	}
	defer closeConn(dtlsConn)

	handshakeCtx, cancelHandshake := context.WithTimeout(ctx, handshakeTimeout)
	defer cancelHandshake()
	if err := dtlsConn.HandshakeContext(handshakeCtx); err != nil {
		return runstage.Wrap(runstage.DTLSHandshake, fmt.Errorf("dtls handshake: %w", err))
	}

	logger.Info("client transport connected",
		"listen", localConn.LocalAddr().String(),
		"turn_addr", r.cfg.TURN.Address,
		"relay_addr", relayConn.LocalAddr().String(),
		"peer", peerAddr.String(),
	)

	if err := runForwarders(ctx, localConn, dtlsConn, logger); err != nil {
		return runstage.Wrap(runstage.ForwardingLoop, err)
	}

	return nil
}

func listenTURNBaseSocket(turnAddr string) (net.PacketConn, error) {
	resolvedAddr, err := net.ResolveUDPAddr("udp", turnAddr)
	if err != nil {
		return nil, fmt.Errorf("resolve turn address %q: %w", turnAddr, err)
	}

	network := "udp"
	listenAddr := ":0"
	if resolvedAddr.IP != nil {
		if resolvedAddr.IP.To4() != nil {
			network = "udp4"
			listenAddr = "0.0.0.0:0"
		} else {
			network = "udp6"
			listenAddr = "[::]:0"
		}
	}

	conn, err := net.ListenPacket(network, listenAddr)
	if err != nil {
		return nil, fmt.Errorf("bind turn client socket: %w", err)
	}

	return conn, nil
}

func runForwarders(ctx context.Context, localConn net.PacketConn, relayConn net.Conn, logger *slog.Logger) error {
	loopCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	stopCancel := context.AfterFunc(loopCtx, func() {
		now := time.Now()
		_ = localConn.SetDeadline(now)
		_ = relayConn.SetDeadline(now)
	})
	defer stopCancel()

	replyTarget := &lastLocalPeer{}
	errCh := make(chan error, 2)

	go func() {
		errCh <- localToRelay(loopCtx, localConn, relayConn, replyTarget)
	}()
	go func() {
		errCh <- relayToLocal(loopCtx, relayConn, localConn, replyTarget, logger)
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

func localToRelay(ctx context.Context, localConn net.PacketConn, relayConn net.Conn, target *lastLocalPeer) error {
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
	}
}

func relayToLocal(ctx context.Context, relayConn net.Conn, localConn net.PacketConn, target *lastLocalPeer, logger *slog.Logger) error {
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

		if _, err := localConn.WriteTo(buf[:n], addr); err != nil {
			if ctx.Err() != nil {
				return nil
			}

			return fmt.Errorf("write local datagram: %w", err)
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
		if value.IP != nil {
			cloned.IP = append([]byte(nil), value.IP...)
		}

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
