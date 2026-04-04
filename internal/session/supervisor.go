package session

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

const workerQueueSize = 64

type workerReadyEvent struct {
	index      int
	generation int
	outbound   chan transport.RelayPacket
}

type workerResult struct {
	index      int
	generation int
	err        error
}

type workerState struct {
	generation int
	restarts   int
	ready      bool
}

func runSupervisedSession(ctx context.Context, localConn net.PacketConn, baseCfg transport.ClientConfig, deps Dependencies, plan sessionPlan, observer observerAPI) error {
	supervisorCtx, cancel := context.WithCancel(ctx)
	defer cancel()

	logger := baseCfg.Logger
	if logger == nil {
		logger = slog.Default()
	}

	stopLocalInterrupt := context.AfterFunc(supervisorCtx, func() {
		_ = localConn.SetDeadline(time.Now())
	})
	defer stopLocalInterrupt()

	router := newLocalRouter(localConn, logger)
	readyCh := make(chan workerReadyEvent, plan.Connections*2)
	resultCh := make(chan workerResult, plan.Connections*2)
	restartCh := make(chan int, plan.Connections*2)
	routerErrCh := make(chan error, 1)

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		routerErrCh <- router.Run(supervisorCtx)
	}()

	states := make([]workerState, plan.Connections)
	startWorker := func(index int, restarting bool) {
		states[index].generation++
		generation := states[index].generation
		outbound := make(chan transport.RelayPacket, workerQueueSize)

		cfg := baseCfg
		cfg.WorkerIndex = index
		cfg.Outbound = outbound
		cfg.Inbound = router.Deliver
		cfg.Logger = logger.With("worker", index, "generation", generation)

		previousReadyHook := cfg.Hooks.OnReady
		cfg.Hooks.OnReady = func() {
			if previousReadyHook != nil {
				previousReadyHook()
			}

			select {
			case readyCh <- workerReadyEvent{
				index:      index,
				generation: generation,
				outbound:   outbound,
			}:
			case <-supervisorCtx.Done():
			}
		}

		runner := deps.NewRunner(cfg)
		wg.Add(1)
		go func() {
			defer wg.Done()

			if restarting {
				cfg.Logger.Info("worker restart started", "restart", states[index].restarts)
			} else {
				cfg.Logger.Info("worker startup started")
			}

			err := runner.Run(supervisorCtx)
			select {
			case resultCh <- workerResult{
				index:      index,
				generation: generation,
				err:        err,
			}:
			case <-supervisorCtx.Done():
			}
		}()
	}

	for index := 0; index < plan.Connections; index++ {
		startWorker(index, false)
	}

	readyWorkers := 0
	sessionReady := false
	var sessionErr error

loop:
	for {
		select {
		case ready := <-readyCh:
			state := &states[ready.index]
			if state.generation != ready.generation || state.ready {
				continue
			}

			state.ready = true
			readyWorkers++
			router.SetReady(ready.index, ready.outbound)
			if observer != nil {
				observer.SetActiveWorkers(readyWorkers)
			}
			logger.Info("session worker ready", "worker", ready.index, "ready_workers", readyWorkers, "connections", plan.Connections)
			if observer != nil {
				observer.Emit(supervisorCtx, slog.LevelInfo, "worker_ready",
					"stage", runstage.SessionSupervise,
					"result", "ready",
					"worker", ready.index,
					"ready_workers", readyWorkers,
					"connections", plan.Connections,
				)
			}
			if !sessionReady && readyWorkers == plan.Connections {
				sessionReady = true
				if observer != nil {
					observer.RecordSessionStart()
					observer.Emit(supervisorCtx, slog.LevelInfo, "runtime_ready",
						"stage", runstage.SessionSupervise,
						"result", "succeeded",
						"connections", plan.Connections,
					)
				}
				logger.Info("supervised session ready", "connections", plan.Connections)
			}

		case result := <-resultCh:
			state := &states[result.index]
			if state.generation != result.generation {
				continue
			}

			wasReady := state.ready
			if wasReady {
				readyWorkers--
				state.ready = false
				router.Remove(result.index)
				if observer != nil {
					observer.SetActiveWorkers(readyWorkers)
				}
			}

			if supervisorCtx.Err() != nil {
				continue
			}

			if result.err == nil {
				if observer != nil {
					observer.RecordTransportFailure(string(runstage.SessionSupervise))
					observer.RecordSessionFailure(string(runstage.SessionSupervise), !sessionReady)
					observer.Emit(supervisorCtx, slog.LevelError, "runtime_failure",
						"stage", runstage.SessionSupervise,
						"result", "failed",
						"worker", result.index,
						"error", fmt.Errorf("worker %d stopped without error", result.index),
					)
				}
				sessionErr = &runstage.Error{
					Stage: runstage.SessionSupervise,
					Err:   fmt.Errorf("worker %d stopped without error", result.index),
				}
				cancel()
				break loop
			}

			if !wasReady {
				if observer != nil {
					observer.RecordTransportFailure(stageString(result.err))
					observer.RecordSessionFailure(stageString(result.err), true)
					observer.Emit(supervisorCtx, slog.LevelError, "runtime_failure",
						"stage", stageString(result.err),
						"result", "failed",
						"worker", result.index,
						"error", result.err,
					)
				}
				sessionErr = result.err
				cancel()
				break loop
			}

			if state.restarts < plan.MaxWorkerRestarts {
				state.restarts++
				if observer != nil {
					observer.RecordTransportFailure(stageString(result.err))
					observer.Emit(supervisorCtx, slog.LevelWarn, "worker_restart_scheduled",
						"stage", stageString(result.err),
						"result", "retrying",
						"worker", result.index,
						"restart", state.restarts,
						"backoff", plan.RestartBackoff,
						"error", result.err,
					)
				}
				logger.Warn("worker failed; scheduling restart",
					"worker", result.index,
					"restart", state.restarts,
					"backoff", plan.RestartBackoff,
					"err", result.err,
				)

				go func(index int) {
					timer := time.NewTimer(plan.RestartBackoff)
					defer timer.Stop()

					select {
					case <-supervisorCtx.Done():
					case <-timer.C:
						select {
						case restartCh <- index:
						case <-supervisorCtx.Done():
						}
					}
				}(result.index)
				continue
			}

			if observer != nil {
				observer.RecordTransportFailure(string(runstage.SessionSupervise))
				observer.RecordSessionFailure(string(runstage.SessionSupervise), false)
				observer.Emit(supervisorCtx, slog.LevelError, "runtime_failure",
					"stage", runstage.SessionSupervise,
					"result", "failed",
					"worker", result.index,
					"restarts", state.restarts,
					"error", fmt.Errorf("worker %d exhausted restart budget after %d restart(s): %w", result.index, state.restarts, result.err),
				)
			}
			sessionErr = &runstage.Error{
				Stage: runstage.SessionSupervise,
				Err: fmt.Errorf(
					"worker %d exhausted restart budget after %d restart(s): %w",
					result.index,
					state.restarts,
					result.err,
				),
			}
			cancel()
			break loop

		case index := <-restartCh:
			if supervisorCtx.Err() != nil {
				continue
			}

			startWorker(index, true)

		case err := <-routerErrCh:
			if err != nil && supervisorCtx.Err() == nil {
				if observer != nil {
					observer.RecordTransportFailure(string(runstage.ForwardingLoop))
					observer.RecordSessionFailure(string(runstage.ForwardingLoop), !sessionReady)
					observer.Emit(supervisorCtx, slog.LevelError, "runtime_failure",
						"stage", runstage.ForwardingLoop,
						"result", "failed",
						"error", err,
					)
				}
				sessionErr = runstage.Wrap(runstage.ForwardingLoop, err)
				cancel()
			}
			break loop

		case <-ctx.Done():
			cancel()
			break loop
		}
	}

	cancel()
	wg.Wait()
	if observer != nil {
		observer.SetActiveWorkers(0)
	}

	if sessionErr != nil {
		return sessionErr
	}
	if ctx.Err() != nil {
		return nil
	}

	select {
	case err := <-routerErrCh:
		if err != nil {
			return runstage.Wrap(runstage.ForwardingLoop, err)
		}
	default:
	}

	return nil
}

type observerAPI interface {
	Emit(context.Context, slog.Level, string, ...any)
	RecordSessionStart()
	RecordSessionFailure(stage string, startup bool)
	RecordTransportFailure(stage string)
	SetActiveWorkers(count int)
}

func stageString(err error) string {
	stage, ok := runstage.FromError(err)
	if !ok {
		return "runtime"
	}

	return string(stage)
}
