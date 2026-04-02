# Project Context

## Purpose
`vk-turn-proxy-go` is the canonical Go repository for a maintainable TURN/DTLS tunnel product.
It is a clean-room successor to `/home/egor/code/vk-turn-proxy`, which remains the compatibility oracle until equivalent behavior is covered by tests here.
The near-term goal is to port legacy client/server behavior behind explicit provider and transport boundaries without a big-bang rewrite.

## Tech Stack
- Go 1.25.x
- Pion DTLS v3 (`github.com/pion/dtls/v3`) and related transport dependencies
- GitHub Actions CI running `go test ./...` and `go build ./...`
- OpenSpec for behavior and architecture change control
- Beads (`bd`) with a Dolt backend for issue tracking

## Project Conventions

### Code Style
- Follow idiomatic Go and the existing package naming/layout in the repository.
- Prefer small packages with one responsibility and avoid files growing beyond roughly 300 lines unless there is a clear reason.
- Use ASCII in edits unless the file already uses Unicode.
- Prefer root-cause fixes over workarounds and avoid speculative abstractions.

### Architecture Patterns
- Keep provider-specific signaling and credential resolution inside `internal/provider/...`.
- Keep TURN/DTLS/UDP transport logic provider-agnostic inside `internal/transport/...`.
- Keep orchestration and lifecycle in `internal/session` and operational binaries in `cmd/...`.
- Keep runtime concerns such as flags, config loading, logging, metrics, and service integration out of transport packages.
- New behavior-changing work must preserve explicit traceability: `requirement -> code -> test`.

### Testing Strategy
- For Go changes, run the smallest relevant test set first, then `go test ./...`, then `go build ./...` when feasible.
- Before changing wire behavior, define the compatibility scenario first.
- Prefer adding or updating an integration/compatibility test over arguing from inspection.
- The legacy repository `/home/egor/code/vk-turn-proxy` is the reference behavior oracle until compatibility coverage exists here.

### Git Workflow
- Use OpenSpec proposals before implementing new capabilities, breaking changes, architecture shifts, or behavior-changing performance/security work.
- Track execution work in Beads instead of markdown TODO lists.
- When an OpenSpec proposal exists, keep `openspec/changes/<change-id>/tasks.md` and the related Beads tasks aligned.
- Validate OpenSpec artifacts with `openspec validate --strict --no-interactive` before handing them off.

## Domain Context
- The product tunnels UDP traffic through TURN/DTLS flows while keeping provider-specific signaling isolated from transport code.
- Primary runtime inputs are provider type/link, local UDP listen address, remote peer/server address, and transport policy flags.
- Expected outputs are a stable tunnel session lifecycle, structured logs with session identifiers, and explicit provider/transport failures.

## Important Constraints
- This repository is the canonical implementation; the legacy repository is for compatibility reference only, not new product changes.
- Do not silently add fallback behavior for provider failures; fail closed with explicit errors.
- Avoid mixed provider + transport + orchestration code in one file.
- Behavior changes should be traceable and backed by tests or an explicit compatibility note.

## External Dependencies
- Legacy compatibility reference: `/home/egor/code/vk-turn-proxy`
- Pion DTLS / transport packages from the Go ecosystem
- GitHub Actions for CI verification
- Beads relies on a Dolt SQL server for write operations in the default backend mode
