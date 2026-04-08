package overlay

import "sync"

type workerRoute struct {
	index    int
	outbound chan Frame
}

type workerSet struct {
	mu      sync.Mutex
	workers []workerRoute
	next    int
}

func (s *workerSet) SetReady(index int, outbound chan Frame) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.removeLocked(index)
	s.workers = append(s.workers, workerRoute{
		index:    index,
		outbound: outbound,
	})
	if s.next >= len(s.workers) {
		s.next = 0
	}
}

func (s *workerSet) Remove(index int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.removeLocked(index)
}

func (s *workerSet) Next() (workerRoute, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if len(s.workers) == 0 {
		return workerRoute{}, false
	}

	worker := s.workers[s.next%len(s.workers)]
	s.next = (s.next + 1) % len(s.workers)
	return worker, true
}

func (s *workerSet) removeLocked(index int) {
	for i, worker := range s.workers {
		if worker.index != index {
			continue
		}

		s.workers = append(s.workers[:i], s.workers[i+1:]...)
		if len(s.workers) == 0 || s.next >= len(s.workers) {
			s.next = 0
		}
		return
	}
}

func routeIDForWorker(index int) uint64 {
	return uint64(index) + 1
}
