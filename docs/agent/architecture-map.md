# Architecture Map

This repository keeps provider logic, transport, runtime orchestration, observability, and compatibility evidence in separate layers.
Use this map to find the owning package before changing code or making claims about behavior.

## Layered flow

1. `cmd/*` parses flags, builds dependencies, and maps runtime errors to process exit behavior.
2. `cmd/clientd` and `pkg/clientcontrol` expose the local client control plane for desktop and embedded hosts.
3. `cmd/android-mobile-host` and `internal/androidembeddedhost` package that same host contract for Android embedded-host delivery.
4. `desktop/gui_shell`, `mobile/gui_shell`, and `packages/flutter_shell_core` implement Flutter-shell surfaces over the typed host semantics.
5. `internal/provider/*` resolves provider credentials and probe artifacts.
6. `internal/session` runs the client runtime after provider resolution.
7. `internal/overlay` owns native ingress/egress adapter framing for the native transport overlay slice.
8. `internal/transport` and `internal/tunnelserver` own TURN/DTLS/UDP data-path mechanics.
9. `internal/turnrest` and `cmd/turn-expiry-check` inspect time-bounded TURN credentials and expiry behavior.
10. `internal/observe` and `internal/runstage` expose structured telemetry and shared runtime stage taxonomy.
11. `test/compatibility/*` and `test/turnlab` anchor compatibility and integration claims with replayable evidence.

## Subsystem map

| Path | Owns | Read when | Primary checks |
| --- | --- | --- | --- |
| `cmd/probe`, `cmd/tunnel-client`, `cmd/tunnel-server`, `cmd/clientd` | CLI flags, dependency wiring, exit/error mapping | Changing flags, startup behavior, stdout/stderr output | `go test ./cmd/...` |
| `cmd/turnlab-shell` | long-lived local turnlab descriptor and manual harness surface | Changing the harness shell, published addresses, or manual smoke workflow | `go test ./test/turnlab -run TestHarnessRelayRoundTrip` |
| `cmd/turn-expiry-check`, `internal/turnrest` | TURN REST expiry parsing and post-expiry Allocate probes | Investigating short-lived TURN usernames or generic-turn expiry behavior | `go test ./internal/turnrest ./cmd/turn-expiry-check` |
| `cmd/android-mobile-host`, `internal/androidembeddedhost` | packaged Android embedded-host bootstrap and native bridge export | Changing mobile packaged-host startup, bridge wiring, or owned-browser host policy | `go test ./internal/androidembeddedhost` |
| `pkg/clientcontrol` | local profile/session/challenge API, event streaming, diagnostics export | Adding GUI-facing control-plane behavior or host wiring | `go test ./pkg/clientcontrol` |
| `packages/flutter_shell_core` | shared Flutter shell core modules and workspace anchor | Extracting app-neutral shell code out of desktop/mobile apps | `dart pub get`; `cd packages/flutter_shell_core && flutter analyze && flutter test` |
| `desktop/gui_shell` | Flutter desktop shell, sidecar supervision, desktop-only UX, diagnostics export workflow | Changing the GUI, sidecar discovery, or desktop lifecycle assumptions | `flutter analyze && flutter test` |
| `mobile/gui_shell` | Flutter mobile shell, secure local state, browser handoff, mobile host bridge lifecycle | Changing the mobile GUI, secure storage behavior, or bridge lifecycle assumptions | `flutter analyze && flutter test` |
| `internal/config` | shared config structs and validation | Adding flags or policy validation | `go test ./internal/config` |
| `internal/provider` | provider registry, artifact shapes, adapter boundary | Any provider-facing behavior change | `go test ./internal/provider/...` |
| `internal/provider/vk` | VK staged resolution, captcha/browser contours, artifact sanitization | VK contour, fixture, or provider failure changes | `go test ./internal/provider/vk ./cmd/probe` |
| `internal/providerprompt` | interactive provider prompts and browser handoff | Interactive VK/operator flow changes or browser continuation refactors | `go test ./internal/providerprompt` |
| `internal/session` | runtime plan, worker supervision, listener routing | Client runtime, restart, or session lifecycle changes | `go test ./internal/session` |
| `internal/overlay` | native overlay frame protocol plus UDP/TCP ingress adapters | Changing native adapter pairing, stream framing, or overlay routing | `go test ./internal/overlay` |
| `internal/transport` | provider-agnostic TURN/DTLS/UDP transport | TURN allocation, relay, or DTLS behavior changes | `go test ./internal/transport` |
| `internal/tunnelserver` | DTLS server runtime and upstream forwarding | Server-side relay/runtime changes | `go test ./internal/tunnelserver` |
| `internal/observe`, `internal/runstage` | metrics surface, structured events, stage taxonomy, and wrapped stage failures | Changing log field names, stage names, or stage-aware error mapping | `go test ./internal/observe ./internal/runstage` |
| `test/compatibility` | compatibility contracts, schemas, fixtures, replay evidence | Any wire-behavior or compatibility claim | provider tests, replay tests |
| `test/turnlab` | deterministic local TURN lab harness | Runtime/transport integration claims | `go test ./test/turnlab` |
| `openspec` | approved behavior and architecture truth | Planning, auditing implementation vs spec, updating contracts | `openspec validate --strict --no-interactive --all` |

## Reference points

- Legacy oracle: `/home/egor/code/vk-turn-proxy`
- Provider support snapshot: `docs/provider-matrix.md`
- Runtime log/metrics contract: `docs/runtime-observability.md`
- Canonical package boundary rationale: `docs/adr/0001-go-monorepo.md`
- Desktop-shell product rules: `.agents/skills/vk-turn-desktop-shell/SKILL.md`
