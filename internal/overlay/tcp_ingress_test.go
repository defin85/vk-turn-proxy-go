package overlay

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net"
	"testing"
	"time"
)

func TestTCPIngressBlockedStreamDoesNotBlockOtherStreams(t *testing.T) {
	streamAConn, streamAPeer := net.Pipe()
	defer streamAPeer.Close()
	streamBConn, streamBPeer := net.Pipe()
	defer streamBPeer.Close()

	ingress := &TCPIngress{
		logger:              slog.New(slog.NewTextHandler(io.Discard, nil)),
		writeTimeout:        20 * time.Millisecond,
		controlFrameTimeout: 50 * time.Millisecond,
		streams:             make(map[uint64]*tcpLocalStream),
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	outboundA := make(chan Frame, 1)
	streamA := &tcpLocalStream{
		id:       1,
		conn:     streamAConn,
		outbound: outboundA,
		inbound:  make(chan Frame, defaultTCPIngressInboundQueueSize),
		done:     make(chan struct{}),
	}
	streamB := &tcpLocalStream{
		id:       2,
		conn:     streamBConn,
		outbound: make(chan Frame, 1),
		inbound:  make(chan Frame, defaultTCPIngressInboundQueueSize),
		done:     make(chan struct{}),
	}

	ingress.storeStream(streamA)
	ingress.storeStream(streamB)

	go ingress.runStreamWriter(ctx, streamA)
	go ingress.runStreamWriter(ctx, streamB)

	deliverDone := make(chan error, 1)
	go func() {
		deliverDone <- ingress.Deliver(Frame{
			Kind:     FrameStreamData,
			StreamID: streamA.id,
			Sequence: 0,
			Payload:  []byte("stream-a-blocked"),
		})
	}()

	select {
	case err := <-deliverDone:
		if err != nil {
			t.Fatalf("Deliver() error = %v", err)
		}
	case <-time.After(100 * time.Millisecond):
		t.Fatal("Deliver() blocked on a stalled local stream")
	}

	payloadCh := make(chan []byte, 1)
	errCh := make(chan error, 1)
	go func() {
		buf := make([]byte, 32)
		if err := streamBPeer.SetReadDeadline(time.Now().Add(time.Second)); err != nil {
			errCh <- err
			return
		}
		n, err := streamBPeer.Read(buf)
		if err != nil {
			errCh <- err
			return
		}
		payloadCh <- append([]byte(nil), buf[:n]...)
	}()

	if err := ingress.Deliver(Frame{
		Kind:     FrameStreamData,
		StreamID: streamB.id,
		Sequence: 0,
		Payload:  []byte("stream-b-ok"),
	}); err != nil {
		t.Fatalf("Deliver() for stream B error = %v", err)
	}

	select {
	case payload := <-payloadCh:
		if got := string(payload); got != "stream-b-ok" {
			t.Fatalf("payload = %q, want %q", got, "stream-b-ok")
		}
	case err := <-errCh:
		t.Fatalf("read stream B payload: %v", err)
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for stream B payload")
	}

	select {
	case frame := <-outboundA:
		if frame.Kind != FrameStreamClose || frame.StreamID != streamA.id {
			t.Fatalf("unexpected close frame %#v", frame)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for stream A close propagation")
	}
}

func TestTCPIngressOutOfOrderFramePropagatesClose(t *testing.T) {
	streamConn, streamPeer := net.Pipe()
	defer streamPeer.Close()

	ingress := &TCPIngress{
		logger:              slog.New(slog.NewTextHandler(io.Discard, nil)),
		writeTimeout:        20 * time.Millisecond,
		controlFrameTimeout: 50 * time.Millisecond,
		streams:             make(map[uint64]*tcpLocalStream),
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	outbound := make(chan Frame, 1)
	stream := &tcpLocalStream{
		id:       7,
		conn:     streamConn,
		outbound: outbound,
		inbound:  make(chan Frame, defaultTCPIngressInboundQueueSize),
		done:     make(chan struct{}),
	}
	ingress.storeStream(stream)

	go ingress.runStreamWriter(ctx, stream)

	if err := ingress.Deliver(Frame{
		Kind:     FrameStreamData,
		StreamID: stream.id,
		Sequence: 1,
		Payload:  []byte("out-of-order"),
	}); err != nil {
		t.Fatalf("Deliver() error = %v", err)
	}

	select {
	case frame := <-outbound:
		if frame.Kind != FrameStreamClose || frame.StreamID != stream.id {
			t.Fatalf("unexpected close frame %#v", frame)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for close propagation")
	}

	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		if ingress.lookupStream(stream.id) == nil {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("stream %d still registered after out-of-order close", stream.id)
}

func TestTCPIngressOutboundBackpressureClosesOnlyBlockedStream(t *testing.T) {
	streamAConn, streamAPeer := net.Pipe()
	defer streamAPeer.Close()
	streamBConn, streamBPeer := net.Pipe()
	defer streamBPeer.Close()

	ingress := &TCPIngress{
		logger:               slog.New(slog.NewTextHandler(io.Discard, nil)),
		writeTimeout:         20 * time.Millisecond,
		outboundFrameTimeout: 20 * time.Millisecond,
		controlFrameTimeout:  20 * time.Millisecond,
		streams:              make(map[uint64]*tcpLocalStream),
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	blockedOutbound := make(chan Frame)
	streamA := &tcpLocalStream{
		id:       1,
		conn:     streamAConn,
		outbound: blockedOutbound,
		inbound:  make(chan Frame, defaultTCPIngressInboundQueueSize),
		done:     make(chan struct{}),
	}
	streamBOutbound := make(chan Frame, 1)
	streamB := &tcpLocalStream{
		id:       2,
		conn:     streamBConn,
		outbound: streamBOutbound,
		inbound:  make(chan Frame, defaultTCPIngressInboundQueueSize),
		done:     make(chan struct{}),
	}

	ingress.storeStream(streamA)
	ingress.storeStream(streamB)

	go ingress.runStreamReader(ctx, streamA)
	go ingress.runStreamReader(ctx, streamB)

	if _, err := streamAPeer.Write([]byte("stream-a-blocked")); err != nil {
		t.Fatalf("write stream A payload: %v", err)
	}

	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		if ingress.lookupStream(streamA.id) == nil {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if ingress.lookupStream(streamA.id) != nil {
		t.Fatalf("stream %d still registered after outbound backpressure", streamA.id)
	}

	if _, err := streamBPeer.Write([]byte("stream-b-ok")); err != nil {
		t.Fatalf("write stream B payload: %v", err)
	}

	select {
	case frame := <-streamBOutbound:
		if frame.Kind != FrameStreamData || frame.StreamID != streamB.id || string(frame.Payload) != "stream-b-ok" {
			t.Fatalf("unexpected outbound frame %#v", frame)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for stream B outbound frame")
	}

	_ = streamAPeer.SetReadDeadline(time.Now().Add(100 * time.Millisecond))
	buf := make([]byte, 1)
	_, err := streamAPeer.Read(buf)
	if !errors.Is(err, io.EOF) && !errors.Is(err, net.ErrClosed) {
		t.Fatalf("stream A peer read error = %v, want EOF or closed", err)
	}
}
