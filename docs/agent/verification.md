# Verification Matrix

Pick the smallest checks that cover the changed behavior first.
If the change crosses package boundaries or affects runtime behavior, escalate to `go test ./...` and `go build ./...` after the focused checks pass.

## Matrix

| Change surface | Read first | Minimum checks | Escalate when |
| --- | --- | --- | --- |
| Docs, `AGENTS.md`, `README.md`, `code_review.md` | `docs/agent/index.md` | verify referenced paths/commands still exist; `git diff --check` | command examples or workflow guidance changed materially |
| CLI flags or config validation | `internal/config`, relevant `cmd/*`, `README.md` | `go test ./internal/config ./cmd/...` | flags affect runtime behavior or shared config semantics |
| Provider-only behavior | `test/compatibility/AGENTS.md`, provider README, relevant spec | `go test ./internal/provider/... ./cmd/probe` | wire behavior, artifacts, or shared runtime flow changed |
| VK contour, fixture, or sanitization work | `test/compatibility/AGENTS.md`, `test/compatibility/vk/README.md` | `go test ./internal/provider/vk ./cmd/probe` | runtime evidence or shared client behavior changed |
| VK runtime evidence or replay expectations | `test/compatibility/vk/runtime/README.md` | `go test ./test/compatibility/vk/runtime -run 'TestRuntimeEvidence(Assets|Replay)'` | runtime/session code changed beyond the evidence layer |
| Desktop Flutter shell or sidecar discovery | `desktop/gui_shell/README.md`, `docs/agent/architecture-map.md`, relevant OpenSpec change | `cd desktop/gui_shell && flutter analyze && flutter test` | packaging/startup behavior changed, sidecar/runtime coupling changed, or a Linux desktop build is part of the acceptance surface |
| Client runtime, routing, or supervision | `openspec/specs/tunnel-client-runtime/spec.md`, `docs/runtime-observability.md` | `go test ./internal/session` | transport, observability, or multiple entrypoints changed |
| TURN/DTLS transport or server runtime | `docs/adr/0001-go-monorepo.md`, `docs/agent/architecture-map.md` | `go test ./internal/transport ./internal/tunnelserver` | relay behavior changed end-to-end or lab harness coverage is needed |
| TURN lab harness changes | `test/turnlab/doc.go`, `README.md` harness section | `go test ./test/turnlab -run TestHarnessRelayRoundTrip` | changes affect runtime/session integration coverage |
| Observability contract | `docs/runtime-observability.md`, `openspec/specs/runtime-observability/spec.md` | `go test ./internal/observe ./cmd/tunnel-client ./cmd/tunnel-server` | emitted stages/fields affect runtime behavior or docs/specs changed together |
| OpenSpec-only updates | `openspec/AGENTS.md` | `openspec validate --strict --no-interactive --all` | the change also modifies code or runtime docs |

## Common escalation set

Run this set after the focused checks pass when a Go change crosses subsystem boundaries:

```bash
go test ./...
go build ./...
```

Compatibility claims should also stay backed by committed fixtures, replay tests, or explicit deviation notes.

For desktop-shell changes that launch the real local host, keep the focused Go verification close to the control-plane boundary:

```bash
go test ./pkg/clientcontrol ./cmd/clientd
```

## GitHub Actions reproduction

Prefer the repo-local `Makefile` entrypoints when the change is sensitive to the GitHub Actions environment rather than just local `go test` behavior:

```bash
make ci-act
```

Use the faster local smoke path when you only need the current Go test/build pair without Docker:

```bash
make ci
```

Use the dry-run path to inspect the job graph without executing containers:

```bash
make ci-act-dry
```

The repo-local `.actrc` still pins `ubuntu-latest` to a full GitHub-like runner image because the `ci` workflow may include browser-backed tests.
The `Makefile` is only a wrapper around the same `act -j test -W .github/workflows/ci.yml` invocation.
