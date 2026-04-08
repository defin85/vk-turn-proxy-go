package overlay

import (
	"context"
	"fmt"
	"log/slog"
	"net"
)

type Ingress interface {
	Run(context.Context) error
	Deliver(Frame) error
	SetReady(index int, outbound chan Frame)
	Remove(index int)
	Close() error
	LocalAddr() net.Addr
}

func NewIngress(kind AdapterKind, listenAddr string, logger *slog.Logger) (Ingress, error) {
	switch NormalizeAdapter(kind) {
	case AdapterUDP:
		return NewUDPIngress(listenAddr, logger)
	case AdapterTCP:
		return NewTCPIngress(listenAddr, logger)
	default:
		return nil, fmt.Errorf("unsupported ingress adapter %q", kind)
	}
}
