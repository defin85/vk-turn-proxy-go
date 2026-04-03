package transport

import (
	"log/slog"
	"net"
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

type TURNCredentials struct {
	Address  string
	Username string
	Password string
}

type ClientConfig struct {
	ListenAddr string
	PeerAddr   string
	TURN       TURNCredentials
	TURNMode   TURNMode
	PeerMode   PeerMode
	BindIP     net.IP
	Logger     *slog.Logger
	Hooks      ClientHooks
}

type ClientHooks struct {
	OnLocalBind     func(net.Addr)
	OnTURNBaseBind  func(net.Addr)
	OnRelayAllocate func(net.Addr)
}
