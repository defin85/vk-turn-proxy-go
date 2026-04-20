# Change: [41] Add VPS server admin web

## Why
Server-side operation on the project VPS currently depends on SSH sessions,
repo-owned shell scripts, ad-hoc log tails, and direct metrics inspection.
That is workable for engineering development, but it is not yet a productized
operator surface for starting, stopping, inspecting, and recovering the
server-side runtime.

The repository already has the ingredients for a safer management surface:
repo-owned build identities, structured runtime observability, and documented
remote workflows. What is missing is one authenticated browser surface on the
VPS that turns those inputs into explicit server-management workflows without
falling back to arbitrary shell access.

## Sequence
- Order: `41`
- Depends on:
  - `add-09-native-build-workflows`
  - `add-11-build-version-surfacing`
- Unblocks:
  - operator-friendly VPS management for repo-owned server runtimes
  - explicit hosted recovery workflows without SSH-first operation
  - future server deployment and hosted diagnostics follow-up work

## What Changes
- Add a first-party authenticated web admin surface for the server-side project
  runtime on the VPS.
- Scope the first slice to an allow-listed set of repo-owned server services,
  explicit runtime status, build identity, recent logs, metrics summaries, and
  controlled lifecycle actions such as start, stop, restart, or reload.
- Keep browser interaction on the supported management path and keep arbitrary
  shell execution, unrestricted process control, and unrelated host inspection
  out of scope.
- Reuse the repository's current build-version and runtime-observability
  surfaces instead of inventing a second undocumented server-status channel.

## Impact
- Affected specs:
  - `server-admin-web`
- Affected code:
  - future `cmd/...` or `internal/...` server-admin backend
  - future browser UI for the VPS operator surface
  - VPS deployment/runbook docs and server-management verification assets
