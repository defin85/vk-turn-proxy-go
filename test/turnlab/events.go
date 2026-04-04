package turnlab

import (
	"context"
	"sync"
)

type maintenanceEvents struct {
	mu                 sync.Mutex
	turnRefreshSuccess int
	changed            chan struct{}
}

func newMaintenanceEvents() *maintenanceEvents {
	return &maintenanceEvents{
		changed: make(chan struct{}),
	}
}

func (e *maintenanceEvents) recordRefreshAuth(verdict bool) {
	if e == nil || !verdict {
		return
	}

	e.mu.Lock()
	e.turnRefreshSuccess++
	close(e.changed)
	e.changed = make(chan struct{})
	e.mu.Unlock()
}

func (e *maintenanceEvents) waitRefreshCount(ctx context.Context, want int) error {
	if e == nil {
		return nil
	}

	for {
		e.mu.Lock()
		if e.turnRefreshSuccess >= want {
			e.mu.Unlock()
			return nil
		}
		changed := e.changed
		e.mu.Unlock()

		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-changed:
		}
	}
}

func (e *maintenanceEvents) refreshCount() int {
	if e == nil {
		return 0
	}

	e.mu.Lock()
	defer e.mu.Unlock()
	return e.turnRefreshSuccess
}
