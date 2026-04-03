package turnlab

import (
	"context"
	"net"
	"sync"
)

type trackingListener struct {
	net.Listener

	mu     sync.Mutex
	active int
	zeroCh chan struct{}
}

func newTrackingListener(listener net.Listener) *trackingListener {
	zeroCh := make(chan struct{})
	close(zeroCh)

	return &trackingListener{
		Listener: listener,
		zeroCh:   zeroCh,
	}
}

func (l *trackingListener) Accept() (net.Conn, error) {
	conn, err := l.Listener.Accept()
	if err != nil {
		return nil, err
	}

	l.mu.Lock()
	if l.active == 0 {
		l.zeroCh = make(chan struct{})
	}
	l.active++
	l.mu.Unlock()

	return &trackedConn{
		Conn: conn,
		onClose: func() {
			l.mu.Lock()
			defer l.mu.Unlock()
			if l.active == 0 {
				return
			}
			l.active--
			if l.active == 0 {
				close(l.zeroCh)
			}
		},
	}, nil
}

func (l *trackingListener) WaitZero(ctx context.Context) error {
	l.mu.Lock()
	ch := l.zeroCh
	if l.active == 0 {
		l.mu.Unlock()
		return nil
	}
	l.mu.Unlock()

	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-ch:
		return nil
	}
}

type trackedConn struct {
	net.Conn

	once    sync.Once
	onClose func()
}

func (c *trackedConn) Close() error {
	err := c.Conn.Close()
	c.once.Do(func() {
		if c.onClose != nil {
			c.onClose()
		}
	})

	return err
}
