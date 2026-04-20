## Context

The repository already has three distinct concepts:

- `resolution`: provider output and same-device startup provenance
- `platform tunnel`: host-owned OS tunnel lifecycle such as Android
  `VpnService`
- `session`: operator-visible runtime lifecycle with stop, diagnostics,
  challenges, and typed events

Live Android validation exposed a gap in the current design:
the packaged host can bring up an Android VPN and report `ready=true`, while
the ordinary `Sessions` surface remains empty.
That makes the product look internally inconsistent even though the underlying
VPN is active.

The current code confirms the split:

- normal session startup creates a typed `Session`
- resolution materialization also creates a typed `Session`
- Android platform-tunnel startup currently returns only typed tunnel status and
  lease state, not a session identity

## Goals / Non-Goals

- Goals:
  - Keep one canonical operator-visible runtime surface across transport paths
  - Ensure a runtime-backed, ready platform tunnel appears through `Sessions`
  - Preserve explicit tunnel-stage reporting for permission, routing, and
    host/runtime attach
  - Keep provenance from runtime session back to originating resolution
- Non-Goals:
  - Redesign the mobile support UI beyond making the existing session surface
    coherent
  - Collapse `resolution`, `platform tunnel`, and `session` into one record
  - Define desktop-specific visual behavior beyond reuse of the same runtime
    contract

## Decisions

### Decision: `Session` remains the only operator-visible runtime identity

`Resolution` stays responsible for provider output and startup provenance.
`Platform tunnel` stays responsible for host-owned OS bring-up and capability
stages.
`Session` remains responsible for stop, diagnostics, challenges, failures, and
active/recent runtime identity.

This avoids competing "truth surfaces" where runtime state could appear under
multiple first-class entities.

### Decision: A runtime-backed ready platform tunnel publishes a canonical session

When platform-tunnel startup reaches `ready=true` after runtime attach, the
host must create or publish the resulting runtime through the canonical session
surface.

The session must link back to the originating resolution when startup was
triggered from a resolution-backed flow.

### Decision: Ready startup returns stable session correlation

The cleanest shell contract is for the ready platform-tunnel result to include
the resulting `session_id`.

This keeps selection and refresh deterministic and avoids shell heuristics.
For mixed-version rollouts, shells can still fall back to refresh plus
resolution/session correlation when the field is absent, but the target
contract for new implementations is explicit `session_id`.

### Decision: Tunnel stages remain separate from session lifecycle

Permission acquisition, route validation, host bring-up, and runtime attach
remain typed platform-tunnel startup concerns.
They should stay visible in start or resume results and diagnostics, not get
collapsed into a fake "session started" bit.

The key rule is:

- before runtime attach success: no ready runtime session
- after runtime attach success: ordinary runtime session exists

## Alternatives Considered

### Alternative: Treat active VPN as sufficient and omit sessions

Rejected.
The Android system VPN indicator does not own stop semantics, diagnostics,
challenges, or runtime failure reporting for this product.
Using VPN state alone would force those concerns back into `resolution` or a
new tunnel-only runtime concept.

### Alternative: Keep a separate tunnel-runtime list in the shell

Rejected.
That creates a second runtime surface competing with `Sessions`, duplicates
operator actions, and makes future desktop parity harder.

### Alternative: Reuse `Resolution` as the live runtime identity

Rejected.
`Resolution` can exist without runtime, can remain useful after runtime stops,
and already has different semantics and lifecycle.

## Risks / Trade-offs

- Adding `session_id` to the startup result extends the typed control-plane
  contract and needs compatibility handling.
- Session creation timing must be disciplined so the host does not publish a
  misleading active session before runtime attach actually succeeds.
- Host cleanup rules must remain strict so a failed attach does not leave an
  orphaned tunnel or zombie session.

## Migration Plan

1. Extend the control-plane contract for ready platform-tunnel results with
   explicit session correlation.
2. Update packaged-host startup internals so successful runtime attach creates
   or publishes the canonical session record.
3. Update the mobile shell to refresh after start or resume and prefer the
   returned `session_id` for activity selection.
4. Add Go and Flutter coverage plus live Android validation showing coherent
   `Resolution` provenance and `Session` activity for the same VPN-backed run.

## Open Questions

- Whether the canonical host implementation should always create a fresh session
  for each successful platform-tunnel startup or may update one existing
  session when the runtime identity is explicitly resumable for the same mode.
- Whether future desktop platform-tunnel modes want the same `session_id`
  guarantee from day one or permit a temporary refresh-only fallback during
  mixed-version rollout.
