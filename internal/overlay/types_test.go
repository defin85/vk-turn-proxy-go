package overlay

import (
	"errors"
	"net"
	"testing"
	"time"
)

func TestFrameMarshalRoundTrip(t *testing.T) {
	testCases := []Frame{
		{Kind: FrameHello, Adapter: AdapterUDP},
		{Kind: FrameHelloAck, Adapter: AdapterTCP},
		{Kind: FrameHelloReject, Reason: "unsupported overlay adapter pair udp -> tcp"},
		{Kind: FrameDatagram, RouteID: 42, Payload: []byte("udp-payload")},
		{Kind: FrameStreamOpen, StreamID: 7},
		{Kind: FrameStreamData, StreamID: 7, Sequence: 3, Payload: []byte("stream-payload")},
		{Kind: FrameStreamClose, StreamID: 7},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.Kind.String(), func(t *testing.T) {
			wire, err := tc.MarshalBinary()
			if err != nil {
				t.Fatalf("MarshalBinary() error = %v", err)
			}

			got, err := UnmarshalFrame(wire)
			if err != nil {
				t.Fatalf("UnmarshalFrame() error = %v", err)
			}

			if got.Kind != tc.Kind {
				t.Fatalf("Kind = %s, want %s", got.Kind, tc.Kind)
			}
			if got.Adapter != tc.Adapter {
				t.Fatalf("Adapter = %s, want %s", got.Adapter, tc.Adapter)
			}
			if got.RouteID != tc.RouteID {
				t.Fatalf("RouteID = %d, want %d", got.RouteID, tc.RouteID)
			}
			if got.StreamID != tc.StreamID {
				t.Fatalf("StreamID = %d, want %d", got.StreamID, tc.StreamID)
			}
			if got.Sequence != tc.Sequence {
				t.Fatalf("Sequence = %d, want %d", got.Sequence, tc.Sequence)
			}
			if string(got.Payload) != string(tc.Payload) {
				t.Fatalf("Payload = %q, want %q", got.Payload, tc.Payload)
			}
			if got.Reason != tc.Reason {
				t.Fatalf("Reason = %q, want %q", got.Reason, tc.Reason)
			}
		})
	}
}

func TestSupportedPair(t *testing.T) {
	if !SupportedPair(AdapterUDP, AdapterUDP) {
		t.Fatal("expected udp -> udp to be supported")
	}
	if !SupportedPair(AdapterTCP, AdapterTCP) {
		t.Fatal("expected tcp -> tcp to be supported")
	}
	if SupportedPair(AdapterUDP, AdapterTCP) {
		t.Fatal("expected udp -> tcp to be rejected")
	}
	if SupportedPair(AdapterTCP, AdapterUDP) {
		t.Fatal("expected tcp -> udp to be rejected")
	}
}

func TestEndpointWriteFrameWithDeadlineTimesOutAndReleasesWriter(t *testing.T) {
	serverConn, clientConn := net.Pipe()
	defer serverConn.Close()
	defer clientConn.Close()

	endpoint := NewEndpoint(serverConn, nil)
	if err := endpoint.WriteFrameWithDeadline(Frame{
		Kind:     FrameStreamClose,
		StreamID: 1,
	}, 20*time.Millisecond); err == nil {
		t.Fatal("expected deadline error")
	} else {
		var netErr net.Error
		if !errors.As(err, &netErr) || !netErr.Timeout() {
			t.Fatalf("deadline write error = %v, want timeout", err)
		}
	}

	frameCh := make(chan Frame, 1)
	errCh := make(chan error, 1)
	go func() {
		buf := make([]byte, 64)
		n, err := clientConn.Read(buf)
		if err != nil {
			errCh <- err
			return
		}
		frame, err := UnmarshalFrame(buf[:n])
		if err != nil {
			errCh <- err
			return
		}
		frameCh <- frame
	}()

	if err := endpoint.WriteFrameWithDeadline(Frame{
		Kind:     FrameStreamClose,
		StreamID: 2,
	}, time.Second); err != nil {
		t.Fatalf("second WriteFrameWithDeadline() error = %v", err)
	}

	select {
	case frame := <-frameCh:
		if frame.Kind != FrameStreamClose || frame.StreamID != 2 {
			t.Fatalf("unexpected frame %#v", frame)
		}
	case err := <-errCh:
		t.Fatalf("read second frame: %v", err)
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for second frame")
	}
}
