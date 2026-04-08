package tunnelserver

import (
	"context"
	"io"
	"log/slog"
	"net"
	"sync"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
)

func TestTCPEgressAdapterBlockedDialDoesNotBlockOtherStreams(t *testing.T) {
	var (
		dialMu        sync.Mutex
		dialCalls     int
		releaseDialCh = make(chan struct{})
		secondDialCh  = make(chan struct{})
	)

	endpoint := &captureFrameWriter{frames: make(chan overlay.Frame, 8)}
	adapter := newTCPEgressAdapter(config.ServerConfig{
		UpstreamAddr:     "127.0.0.1:0",
		IdleTimeout:      5 * time.Second,
		HandshakeTimeout: time.Second,
	}, endpoint, slog.New(slog.NewTextHandler(io.Discard, nil)), observe.NewObserver(observe.RuntimeServer, slog.New(slog.NewTextHandler(io.Discard, nil)), nil, observe.Metadata{}), "remote")

	stream2ServerConn, stream2ClientConn := net.Pipe()
	defer stream2ClientConn.Close()

	adapter.dialContext = func(ctx context.Context, network string, address string) (net.Conn, error) {
		dialMu.Lock()
		dialCalls++
		call := dialCalls
		dialMu.Unlock()

		if call == 1 {
			select {
			case <-releaseDialCh:
				return nil, context.Canceled
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		}
		close(secondDialCh)
		return stream2ServerConn, nil
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	firstOpenDone := make(chan error, 1)
	go func() {
		firstOpenDone <- adapter.HandleFrame(ctx, overlay.Frame{
			Kind:     overlay.FrameStreamOpen,
			StreamID: 1,
		})
	}()

	select {
	case err := <-firstOpenDone:
		if err != nil {
			t.Fatalf("first open error = %v", err)
		}
	case <-time.After(200 * time.Millisecond):
		t.Fatal("first open blocked on upstream dial")
	}

	if err := adapter.HandleFrame(ctx, overlay.Frame{
		Kind:     overlay.FrameStreamOpen,
		StreamID: 2,
	}); err != nil {
		t.Fatalf("second open error = %v", err)
	}

	select {
	case <-secondDialCh:
	case <-time.After(time.Second):
		t.Fatal("stream 2 dial did not start while stream 1 was blocked")
	}

	close(releaseDialCh)
	_ = stream2ServerConn.Close()
}

type captureFrameWriter struct {
	frames chan overlay.Frame
}

func (w *captureFrameWriter) WriteFrame(frame overlay.Frame) error {
	select {
	case w.frames <- frame:
		return nil
	case <-time.After(time.Second):
		return context.DeadlineExceeded
	}
}
