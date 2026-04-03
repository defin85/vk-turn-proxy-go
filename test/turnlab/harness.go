package turnlab

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/url"
	"sync"
	"time"

	"github.com/pion/turn/v4"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/tunnelserver"
)

const (
	loopbackAddress  = "127.0.0.1"
	turnUsername     = "turn-lab-user"
	turnPassword     = "turn-lab-pass"
	turnRealm        = "turn.lab"
	handshakeTimeout = 5 * time.Second
	idleTimeout      = 5 * time.Second
)

type TURNCredentials struct {
	Username string
	Password string
	Realm    string
}

type Descriptor struct {
	TURNAddress     string
	TURNCredentials TURNCredentials
	PeerAddress     string
	UpstreamAddress string
}

func (d Descriptor) GenericTurnLink() string {
	if d.TURNAddress == "" {
		return ""
	}

	return (&url.URL{
		Scheme: "generic-turn",
		User:   url.UserPassword(d.TURNCredentials.Username, d.TURNCredentials.Password),
		Host:   d.TURNAddress,
	}).String()
}

type Harness struct {
	Descriptor Descriptor

	cancel   context.CancelFunc
	done     chan struct{}
	closeErr error
	once     sync.Once
}

func Start(parent context.Context, logger *slog.Logger) (*Harness, error) {
	if parent == nil {
		parent = context.Background()
	}
	if logger == nil {
		logger = slog.Default()
	}
	if err := parent.Err(); err != nil {
		return nil, fmt.Errorf("start harness: %w", err)
	}

	ctx, cancel := context.WithCancel(parent)
	harness := &Harness{
		cancel: cancel,
		done:   make(chan struct{}),
		Descriptor: Descriptor{
			TURNCredentials: TURNCredentials{
				Username: turnUsername,
				Password: turnPassword,
				Realm:    turnRealm,
			},
		},
	}

	echoConn, err := net.ListenPacket("udp4", loopbackAddress+":0")
	if err != nil {
		cancel()
		return nil, fmt.Errorf("listen upstream echo: %w", err)
	}

	echoErrCh := make(chan error, 1)
	go func() {
		echoErrCh <- runUDPEcho(echoConn)
		close(echoErrCh)
	}()
	harness.Descriptor.UpstreamAddress = echoConn.LocalAddr().String()

	peerServer, err := tunnelserver.New(config.ServerConfig{
		ListenAddr:       loopbackAddress + ":0",
		UpstreamAddr:     harness.Descriptor.UpstreamAddress,
		HandshakeTimeout: handshakeTimeout,
		IdleTimeout:      idleTimeout,
	}, logger)
	if err != nil {
		cancel()
		_ = echoConn.Close()
		<-echoErrCh
		return nil, fmt.Errorf("create peer server: %w", err)
	}

	peerListener, err := peerServer.Listen()
	if err != nil {
		cancel()
		_ = echoConn.Close()
		<-echoErrCh
		return nil, fmt.Errorf("listen peer server: %w", err)
	}

	peerErrCh := make(chan error, 1)
	go func() {
		peerErrCh <- peerServer.Serve(ctx, peerListener)
		close(peerErrCh)
	}()
	harness.Descriptor.PeerAddress = peerListener.Addr().String()

	turnConn, err := net.ListenPacket("udp4", loopbackAddress+":0")
	if err != nil {
		cancel()
		_ = peerListener.Close()
		<-peerErrCh
		_ = echoConn.Close()
		<-echoErrCh
		return nil, fmt.Errorf("listen turn server: %w", err)
	}

	turnServer, err := turn.NewServer(turn.ServerConfig{
		Realm:       turnRealm,
		AuthHandler: staticAuthHandler(),
		PacketConnConfigs: []turn.PacketConnConfig{
			{
				PacketConn: turnConn,
				RelayAddressGenerator: &turn.RelayAddressGeneratorStatic{
					RelayAddress: net.ParseIP(loopbackAddress),
					Address:      loopbackAddress,
				},
			},
		},
	})
	if err != nil {
		cancel()
		_ = turnConn.Close()
		_ = peerListener.Close()
		<-peerErrCh
		_ = echoConn.Close()
		<-echoErrCh
		return nil, fmt.Errorf("start turn server: %w", err)
	}
	harness.Descriptor.TURNAddress = turnConn.LocalAddr().String()

	go func() {
		<-ctx.Done()

		errs := make([]error, 0, 5)
		if err := turnServer.Close(); err != nil {
			errs = append(errs, fmt.Errorf("close turn server: %w", err))
		}
		if err := peerListener.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			errs = append(errs, fmt.Errorf("close peer listener: %w", err))
		}
		if err := echoConn.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			errs = append(errs, fmt.Errorf("close upstream echo: %w", err))
		}
		if err := <-peerErrCh; err != nil {
			errs = append(errs, fmt.Errorf("peer server: %w", err))
		}
		if err := <-echoErrCh; err != nil && !errors.Is(err, net.ErrClosed) {
			errs = append(errs, fmt.Errorf("upstream echo: %w", err))
		}

		harness.closeErr = errors.Join(errs...)
		close(harness.done)
	}()

	if err := ctx.Err(); err != nil {
		if closeErr := harness.Close(); closeErr != nil {
			return nil, errors.Join(fmt.Errorf("start harness: %w", err), closeErr)
		}

		return nil, fmt.Errorf("start harness: %w", err)
	}

	return harness, nil
}

func (h *Harness) Close() error {
	if h == nil {
		return nil
	}

	h.once.Do(func() {
		h.cancel()
	})
	<-h.done

	return h.closeErr
}

func (h *Harness) GenericTurnLink() string {
	if h == nil {
		return ""
	}

	return h.Descriptor.GenericTurnLink()
}

func staticAuthHandler() func(string, string, net.Addr) ([]byte, bool) {
	key := turn.GenerateAuthKey(turnUsername, turnRealm, turnPassword)

	return func(username string, realm string, _ net.Addr) ([]byte, bool) {
		if username != turnUsername || realm != turnRealm {
			return nil, false
		}

		return key, true
	}
}
