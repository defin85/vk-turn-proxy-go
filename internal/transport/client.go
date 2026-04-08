package transport

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"time"

	"github.com/pion/turn/v5"

	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
)

type clientRunner struct {
	cfg ClientConfig
}

const standaloneWorkerQueueSize = 64

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

	ingress, ownIngress, err := r.openIngress(logger)
	if err != nil {
		return err
	}
	if ownIngress {
		defer closeIngress(ingress)
	}
	if ingress != nil && r.cfg.Hooks.OnLocalBind != nil {
		r.cfg.Hooks.OnLocalBind(cloneAddr(ingress.LocalAddr()))
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

	var endpoint *overlay.Endpoint
	if r.cfg.PeerMode == PeerModeDTLS {
		endpoint = overlay.NewEndpoint(peerConn, logger)
		if err := performClientOverlayHandshake(peerConn, endpoint, r.cfg.Ingress); err != nil {
			return runstage.Wrap(runstage.PeerSetup, err)
		}
	}

	if ownIngress {
		if err := r.runStandaloneIngress(ctx, ingress); err != nil {
			return runstage.Wrap(runstage.ForwardingLoop, err)
		}
	}

	listenAddr := r.cfg.ListenAddr
	if ingress != nil && ingress.LocalAddr() != nil {
		listenAddr = ingress.LocalAddr().String()
	}

	logger.Info("client transport connected",
		"listen", listenAddr,
		"turn_addr", r.cfg.TURN.Address,
		"turn_mode", r.cfg.TURNMode,
		"relay_mode", r.cfg.PeerMode,
		"relay_addr", relayConn.LocalAddr().String(),
		"peer", peerAddr,
		"ingress", r.cfg.Ingress,
	)

	if r.cfg.Hooks.OnReady != nil {
		r.cfg.Hooks.OnReady()
	}

	if err := r.runForwarders(ctx, peerConn, endpoint, logger); err != nil {
		return runstage.Wrap(runstage.ForwardingLoop, err)
	}

	return nil
}

func (r *clientRunner) openIngress(logger *slog.Logger) (overlay.Ingress, bool, error) {
	if r.cfg.Outbound != nil || r.cfg.Inbound != nil {
		if r.cfg.Outbound == nil || r.cfg.Inbound == nil {
			return nil, false, fmt.Errorf("supervised worker transport requires both outbound and inbound hooks")
		}

		return nil, false, nil
	}

	ingress, err := overlay.NewIngress(r.cfg.Ingress, r.cfg.ListenAddr, logger)
	if err != nil {
		return nil, false, runstage.Wrap(runstage.LocalBind, err)
	}

	return ingress, true, nil
}

func (r *clientRunner) runStandaloneIngress(ctx context.Context, ingress overlay.Ingress) error {
	outbound := make(chan overlay.Frame, standaloneWorkerQueueSize)
	ingress.SetReady(0, outbound)
	r.cfg.Outbound = outbound
	r.cfg.Inbound = ingress.Deliver

	go func() {
		_ = ingress.Run(ctx)
	}()

	go func() {
		<-ctx.Done()
		_ = ingress.Close()
	}()

	return nil
}

func (r *clientRunner) runForwarders(ctx context.Context, peerConn net.Conn, endpoint *overlay.Endpoint, logger *slog.Logger) error {
	switch {
	case r.cfg.Outbound == nil || r.cfg.Inbound == nil:
		return fmt.Errorf("transport forwarders require outbound and inbound hooks")
	case r.cfg.PeerMode == PeerModeDTLS:
		return runOverlayForwarders(ctx, r.cfg.Outbound, r.cfg.Inbound, endpoint, peerConn, logger, r.cfg.Hooks.OnTraffic)
	case r.cfg.PeerMode == PeerModePlain && overlay.NormalizeAdapter(r.cfg.Ingress) == overlay.AdapterUDP:
		return runDirectDatagramForwarders(ctx, r.cfg.Outbound, r.cfg.Inbound, peerConn, logger, r.cfg.Hooks.OnTraffic)
	default:
		return fmt.Errorf("unsupported overlay runtime for peer_mode=%q ingress=%q", r.cfg.PeerMode, r.cfg.Ingress)
	}
}

func performClientOverlayHandshake(conn net.Conn, endpoint *overlay.Endpoint, ingress overlay.AdapterKind) error {
	if err := conn.SetDeadline(time.Now().Add(handshakeTimeout)); err != nil {
		return fmt.Errorf("set overlay handshake deadline: %w", err)
	}
	defer func() {
		_ = conn.SetDeadline(time.Time{})
	}()

	if err := endpoint.WriteFrame(overlay.Frame{
		Kind:    overlay.FrameHello,
		Adapter: overlay.NormalizeAdapter(ingress),
	}); err != nil {
		return fmt.Errorf("write overlay hello: %w", err)
	}

	frame, err := endpoint.ReadFrame()
	if err != nil {
		return fmt.Errorf("read overlay hello response: %w", err)
	}

	switch frame.Kind {
	case overlay.FrameHelloAck:
		if !overlay.SupportedPair(overlay.NormalizeAdapter(ingress), frame.Adapter) {
			return fmt.Errorf("unsupported overlay adapter pair %s -> %s", ingress, frame.Adapter)
		}
		return nil
	case overlay.FrameHelloReject:
		if frame.Reason == "" {
			frame.Reason = "overlay pairing rejected"
		}
		return errors.New(frame.Reason)
	default:
		return fmt.Errorf("unexpected overlay handshake frame %s", frame.Kind)
	}
}

func closeIngress(ingress overlay.Ingress) {
	if ingress == nil {
		return
	}

	_ = ingress.Close()
}
