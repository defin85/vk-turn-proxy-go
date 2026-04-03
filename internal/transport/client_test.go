package transport

import (
	"net"
	"testing"
)

func TestLastLocalPeerKeepsMostRecentSender(t *testing.T) {
	peer := &lastLocalPeer{}

	first := &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: 10001}
	second := &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: 10002}

	peer.Store(first)
	peer.Store(second)

	got, ok := peer.Load()
	if !ok {
		t.Fatal("expected stored peer")
	}

	udpAddr, ok := got.(*net.UDPAddr)
	if !ok {
		t.Fatalf("unexpected addr type %T", got)
	}
	if udpAddr.String() != second.String() {
		t.Fatalf("unexpected addr %s want %s", udpAddr.String(), second.String())
	}

	second.Port = 10003
	if udpAddr.Port != 10002 {
		t.Fatalf("loaded addr should be cloned, got port %d", udpAddr.Port)
	}
}
