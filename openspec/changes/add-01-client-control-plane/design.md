## Context

The repository already has the hard part of transport startup, provider resolution, supervision, and observability.
What it does not have is a stable application-facing API that a GUI can depend on across desktop and mobile platforms.

Without a control plane, every future client would need to:

- shell out to CLI binaries
- parse human-oriented stderr and logs
- invent its own profile store and session model
- guess how browser challenges or diagnostics should work

That would fragment behavior across platforms and make compatibility hard to reason about.

## Goals

- Provide one stable local API for profile management, session lifecycle, challenge handoff, event streaming, and diagnostics
- Keep provider and transport boundaries intact
- Support both desktop sidecar hosting and mobile in-process hosting through the same logical contract
- Make version mismatch and unsupported capability detection explicit

## Non-Goals

- Deliver a GUI in this change
- Add native transport overlay adapters
- Add system tunnel or route-management behavior
- Commit to a remote/cloud control plane

## Decisions

### Decision: Use a local control plane instead of GUI-to-CLI parsing

Desktop and mobile shells should talk to a stable API, not parse logs or process output.
This keeps UI code decoupled from runtime internals and makes compatibility versionable.

### Decision: Make the control plane local-only and host-scoped

The first client control plane is local to the device.
Desktop shells use a sidecar daemon over local IPC; mobile shells use the same logical API through a host bridge.

### Decision: Model sessions, challenges, and diagnostics as first-class resources

The API must expose typed profile IDs, session IDs, challenge tokens, and diagnostics artifacts instead of hiding them behind free-form log lines.

### Decision: Require capability and version negotiation

GUI shells and hosts must fail fast when the local host implementation is too old, missing an adapter, or lacks a required platform capability.

## Alternatives Considered

### Reuse `cmd/tunnel-client` directly from the GUI

Rejected.
That would couple the GUI to flag parsing, log text, and OS-specific process supervision.

### Build separate desktop and mobile APIs

Rejected.
That would duplicate profile, session, and challenge semantics before the first GUI even ships.

## Risks / Trade-offs

- A new control plane adds API maintenance overhead
- Typed event and challenge flows must remain stable as provider/runtime behavior evolves
- Cross-platform host bindings can drift if the local API surface is not kept minimal and versioned

## Validation Plan

- Unit coverage for profile/session/challenge state transitions
- Integration tests that start sessions through the control plane rather than only through CLI flags
- Explicit compatibility/version negotiation tests
- `openspec validate add-01-client-control-plane --strict --no-interactive`
