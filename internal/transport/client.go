package transport

import (
	"context"
	"fmt"
	"log/slog"
	"net"

	"github.com/pion/turn/v5"

	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
)

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

	localConn, ownLocal, err := r.openLocalConn()
	if err != nil {
		return err
	}
	if ownLocal {
		defer closePacketConn(localConn)
	}
	if localConn != nil && r.cfg.Hooks.OnLocalBind != nil {
		r.cfg.Hooks.OnLocalBind(cloneAddr(localConn.LocalAddr()))
	}

	baseConn, err := openTURNBaseConn(ctx, r.cfg)
	if err != nil {
		return runstage.Wrap(runstage.TURNDial, err)
	}
	defer closePacketConn(baseConn)
	if r.cfg.Hooks.OnTURNBaseBind != nil {
		r.cfg.Hooks.OnTURNBaseBind(cloneAddr(baseConn.LocalAddr()))
	}

	turnNet, err := newTURNNet(r.cfg.BindIP)
	if err != nil {
		return runstage.Wrap(runstage.TURNDial, fmt.Errorf("create turn network: %w", err))
	}

	client, err := turn.NewClient(&turn.ClientConfig{
		STUNServerAddr: r.cfg.TURN.Address,
		TURNServerAddr: r.cfg.TURN.Address,
		Conn:           baseConn,
		Net:            turnNet,
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

	peerConn, peerAddr, err := openPeerRelay(ctx, relayConn, r.cfg)
	if err != nil {
		return err
	}
	defer closeConn(peerConn)

	listenAddr := r.cfg.ListenAddr
	if localConn != nil {
		listenAddr = localConn.LocalAddr().String()
	}

	logger.Info("client transport connected",
		"listen", listenAddr,
		"turn_addr", r.cfg.TURN.Address,
		"turn_mode", r.cfg.TURNMode,
		"relay_mode", r.cfg.PeerMode,
		"relay_addr", relayConn.LocalAddr().String(),
		"peer", peerAddr,
	)

	if r.cfg.Hooks.OnReady != nil {
		r.cfg.Hooks.OnReady()
	}

	if err := r.runForwarders(ctx, localConn, peerConn, logger, ownLocal); err != nil {
		return runstage.Wrap(runstage.ForwardingLoop, err)
	}

	return nil
}

func (r *clientRunner) openLocalConn() (net.PacketConn, bool, error) {
	if r.cfg.Outbound != nil || r.cfg.Inbound != nil {
		if r.cfg.Outbound == nil || r.cfg.Inbound == nil {
			return nil, false, fmt.Errorf("supervised worker transport requires both outbound and inbound hooks")
		}

		return nil, false, nil
	}

	localConn, err := net.ListenPacket("udp", r.cfg.ListenAddr)
	if err != nil {
		return nil, false, runstage.Wrap(runstage.LocalBind, fmt.Errorf("bind local listener: %w", err))
	}

	return localConn, true, nil
}

func (r *clientRunner) runForwarders(ctx context.Context, localConn net.PacketConn, relayConn net.Conn, logger *slog.Logger, ownLocal bool) error {
	if r.cfg.Outbound != nil || r.cfg.Inbound != nil {
		return runChannelForwarders(ctx, r.cfg.Outbound, r.cfg.Inbound, relayConn, logger, r.cfg.Hooks.OnTraffic)
	}

	return runPacketConnForwarders(ctx, localConn, relayConn, logger, ownLocal, r.cfg.Hooks.OnTraffic)
}
