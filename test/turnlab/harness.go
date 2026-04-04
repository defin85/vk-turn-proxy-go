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

	"github.com/pion/turn/v5"

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

type Options struct {
	AcceptedCredentials []TURNCredentials
	AllocationLifetime  time.Duration
	PermissionTimeout   time.Duration
	ChannelBindTimeout  time.Duration
}

type Descriptor struct {
	TURNAddress     string
	TURNTCPAddress  string
	TURNCredentials TURNCredentials
	PeerAddress     string
	UpstreamAddress string
}

func (d Descriptor) GenericTurnLink() string {
	return d.GenericTurnLinkForAddress(d.TURNAddress)
}

func (d Descriptor) GenericTurnTCPLink() string {
	return d.GenericTurnLinkForAddress(d.TURNTCPAddress)
}

func (d Descriptor) GenericTurnLinkForAddress(address string) string {
	if address == "" {
		return ""
	}

	return (&url.URL{
		Scheme: "generic-turn",
		User:   url.UserPassword(d.TURNCredentials.Username, d.TURNCredentials.Password),
		Host:   address,
	}).String()
}

type Harness struct {
	Descriptor Descriptor

	upstream *upstreamController
	events   *maintenanceEvents
	turnTCP  *trackingListener
	cancel   context.CancelFunc
	done     chan struct{}
	closeErr error
	once     sync.Once
}

func Start(parent context.Context, logger *slog.Logger) (*Harness, error) {
	return StartWithOptions(parent, logger, Options{})
}

func StartWithOptions(parent context.Context, logger *slog.Logger, opts Options) (*Harness, error) {
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
		events: newMaintenanceEvents(),
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
	upstream := newUpstreamController(echoConn)
	harness.upstream = upstream

	echoErrCh := make(chan error, 1)
	go func() {
		echoErrCh <- upstream.run()
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
	tcpListener, err := net.Listen("tcp4", loopbackAddress+":0")
	if err != nil {
		cancel()
		_ = turnConn.Close()
		_ = peerListener.Close()
		<-peerErrCh
		_ = echoConn.Close()
		<-echoErrCh
		return nil, fmt.Errorf("listen turn tcp server: %w", err)
	}
	trackingTCPListener := newTrackingListener(tcpListener)
	harness.turnTCP = trackingTCPListener

	turnServer, err := turn.NewServer(turn.ServerConfig{
		Realm:              turnRealm,
		AuthHandler:        staticAuthHandler(opts.AcceptedCredentials),
		AllocationLifetime: opts.AllocationLifetime,
		PermissionTimeout:  opts.PermissionTimeout,
		ChannelBindTimeout: opts.ChannelBindTimeout,
		EventHandler: turn.EventHandler{
			OnAuth: func(_, _ net.Addr, _, _, _, method string, verdict bool) {
				if method == "Refresh" {
					harness.events.recordRefreshAuth(verdict)
				}
			},
		},
		PacketConnConfigs: []turn.PacketConnConfig{
			{
				PacketConn: turnConn,
				RelayAddressGenerator: &turn.RelayAddressGeneratorStatic{
					RelayAddress: net.ParseIP(loopbackAddress),
					Address:      loopbackAddress,
				},
			},
		},
		ListenerConfigs: []turn.ListenerConfig{
			{
				Listener: trackingTCPListener,
				RelayAddressGenerator: &turn.RelayAddressGeneratorStatic{
					RelayAddress: net.ParseIP(loopbackAddress),
					Address:      loopbackAddress,
				},
			},
		},
	})
	if err != nil {
		cancel()
		_ = trackingTCPListener.Close()
		_ = turnConn.Close()
		_ = peerListener.Close()
		<-peerErrCh
		_ = echoConn.Close()
		<-echoErrCh
		return nil, fmt.Errorf("start turn server: %w", err)
	}
	harness.Descriptor.TURNAddress = turnConn.LocalAddr().String()
	harness.Descriptor.TURNTCPAddress = trackingTCPListener.Addr().String()

	go func() {
		<-ctx.Done()

		errs := make([]error, 0, 6)
		if err := turnServer.Close(); err != nil {
			errs = append(errs, fmt.Errorf("close turn server: %w", err))
		}
		if err := trackingTCPListener.Close(); err != nil && !errors.Is(err, net.ErrClosed) {
			errs = append(errs, fmt.Errorf("close turn tcp listener: %w", err))
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

func (h *Harness) WaitUpstreamPeer(ctx context.Context) (net.Addr, error) {
	if h == nil || h.upstream == nil {
		return nil, errors.New("harness upstream is not available")
	}

	return h.upstream.WaitPeer(ctx)
}

func (h *Harness) InjectUpstream(payload []byte) error {
	if h == nil || h.upstream == nil {
		return errors.New("harness upstream is not available")
	}

	return h.upstream.Inject(payload)
}

func (h *Harness) WaitNoActiveTURNTCPConns(ctx context.Context) error {
	if h == nil || h.turnTCP == nil {
		return errors.New("harness turn tcp listener is not available")
	}

	return h.turnTCP.WaitZero(ctx)
}

func (h *Harness) WaitRefreshCount(ctx context.Context, want int) error {
	if h == nil || h.events == nil {
		return errors.New("harness maintenance events are not available")
	}

	return h.events.waitRefreshCount(ctx, want)
}

func (h *Harness) RefreshCount() int {
	if h == nil || h.events == nil {
		return 0
	}

	return h.events.refreshCount()
}

func staticAuthHandler(extra []TURNCredentials) func(*turn.RequestAttributes) (string, []byte, bool) {
	keys := map[string][]byte{
		authIdentity(turnUsername, turnRealm): turn.GenerateAuthKey(turnUsername, turnRealm, turnPassword),
	}
	for _, creds := range extra {
		username := creds.Username
		if username == "" {
			continue
		}

		realm := creds.Realm
		if realm == "" {
			realm = turnRealm
		}
		if creds.Password == "" {
			continue
		}

		keys[authIdentity(username, realm)] = turn.GenerateAuthKey(username, realm, creds.Password)
	}

	return func(attrs *turn.RequestAttributes) (string, []byte, bool) {
		if attrs == nil {
			return "", nil, false
		}

		key, ok := keys[authIdentity(attrs.Username, attrs.Realm)]
		return attrs.Username, key, ok
	}
}

func authIdentity(username string, realm string) string {
	return username + "\x00" + realm
}
