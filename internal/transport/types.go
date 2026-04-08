package transport

import (
	"log/slog"
	"net"

	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
)

type TURNMode string

const (
	TURNModeUDP TURNMode = "udp"
	TURNModeTCP TURNMode = "tcp"
)

type PeerMode string

const (
	PeerModeDTLS  PeerMode = "dtls"
	PeerModePlain PeerMode = "plain"
)

const (
	TrafficDirectionLocalToRelay = "local_to_relay"
	TrafficDirectionRelayToLocal = "relay_to_local"
)

type TURNCredentials struct {
	Address  string
	Username string
	Password string
}

type ClientConfig struct {
	ListenAddr  string
	PeerAddr    string
	Ingress     overlay.AdapterKind
	TURN        TURNCredentials
	TURNMode    TURNMode
	PeerMode    PeerMode
	BindIP      net.IP
	WorkerIndex int
	Outbound    <-chan overlay.Frame
	Inbound     func(overlay.Frame) error
	Logger      *slog.Logger
	Hooks       ClientHooks
}

type ClientHooks struct {
	OnLocalBind     func(net.Addr)
	OnTURNBaseBind  func(net.Addr)
	OnRelayAllocate func(net.Addr)
	OnTraffic       func(direction string, bytes int)
	OnReady         func()
}
