package transport

import (
	"log/slog"
	"net"
)

type RelayPacket struct {
	Payload []byte
	ReplyTo net.Addr
}

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
	TURN        TURNCredentials
	TURNMode    TURNMode
	PeerMode    PeerMode
	BindIP      net.IP
	WorkerIndex int
	Outbound    <-chan RelayPacket
	Inbound     func(RelayPacket) error
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
