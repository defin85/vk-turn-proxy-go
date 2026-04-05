# Architecture Map

This repository keeps provider logic, transport, runtime orchestration, observability, and compatibility evidence in separate layers.
Use this map to find the owning package before changing code or making claims about behavior.

## Layered flow

1. `cmd/*` parses flags, builds dependencies, and maps runtime errors to process exit behavior.
2. `cmd/clientd` and `pkg/clientcontrol` expose the local client control plane for desktop and embedded hosts.
3. `internal/provider/*` resolves provider credentials and probe artifacts.
4. `internal/session` runs the client runtime after provider resolution.
5. `internal/transport` and `internal/tunnelserver` own TURN/DTLS/UDP data-path mechanics.
6. `internal/observe` emits structured events and metrics around runtime stages.
7. `test/compatibility/*` and `test/turnlab` anchor compatibility and integration claims with replayable evidence.

## Subsystem map

| Path | Owns | Read when | Primary checks |
| --- | --- | --- | --- |
| `cmd/probe`, `cmd/tunnel-client`, `cmd/tunnel-server`, `cmd/clientd` | CLI flags, dependency wiring, exit/error mapping | Changing flags, startup behavior, stdout/stderr output | `go test ./cmd/...` |
| `pkg/clientcontrol` | local profile/session/challenge API, event streaming, diagnostics export | Adding GUI-facing control-plane behavior or host wiring | `go test ./pkg/clientcontrol` |
| `internal/config` | shared config structs and validation | Adding flags or policy validation | `go test ./internal/config` |
| `internal/provider` | provider registry, artifact shapes, adapter boundary | Any provider-facing behavior change | `go test ./internal/provider/...` |
| `internal/provider/vk` | VK staged resolution, captcha/browser contours, artifact sanitization | VK contour, fixture, or provider failure changes | `go test ./internal/provider/vk ./cmd/probe` |
| `internal/providerprompt` | interactive provider prompts and browser handoff | Interactive VK/operator flow changes or browser continuation refactors | `go test ./internal/providerprompt` |
| `internal/session` | runtime plan, worker supervision, listener routing | Client runtime, restart, or session lifecycle changes | `go test ./internal/session` |
| `internal/transport` | provider-agnostic TURN/DTLS/UDP transport | TURN allocation, relay, or DTLS behavior changes | `go test ./internal/transport` |
| `internal/tunnelserver` | DTLS server runtime and upstream forwarding | Server-side relay/runtime changes | `go test ./internal/tunnelserver` |
| `internal/observe` | metrics surface, structured logs, runtime metadata | Metrics/log schema changes | `go test ./internal/observe` |
| `test/compatibility` | compatibility contracts, schemas, fixtures, replay evidence | Any wire-behavior or compatibility claim | provider tests, replay tests |
| `test/turnlab` | deterministic local TURN lab harness | Runtime/transport integration claims | `go test ./test/turnlab` |
| `openspec` | approved behavior and architecture truth | Planning, auditing implementation vs spec, updating contracts | `openspec validate --strict --no-interactive --all` |

## Reference points

- Legacy oracle: `/home/egor/code/vk-turn-proxy`
- Provider support snapshot: `docs/provider-matrix.md`
- Runtime log/metrics contract: `docs/runtime-observability.md`
- Canonical package boundary rationale: `docs/adr/0001-go-monorepo.md`
