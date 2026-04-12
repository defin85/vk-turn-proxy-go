## Context
The repository already has the core pieces needed to reach transport-ready TURN
credentials:

- provider-specific live resolution
- typed challenge continuation through the local host
- desktop and mobile shells over the same control-plane model
- a deterministic `generic-turn://...` representation for static TURN
  credentials

What it does not have is one shared handoff contract that turns a successful
provider resolution into a reusable product artifact across platforms.

Today that final handoff exists only in `cmd/probe` as an opt-in CLI printout.
That is useful for operator debugging, but it is not a product contract:
desktop cannot start from a typed resolved artifact, mobile cannot explicitly
share it, and the host cannot enforce one redaction/expiry boundary for all
platforms.

## Goals
- Define one platform-neutral host contract for provider resolution and handoff.
- Keep provider resolution separate from runtime session startup.
- Support both same-device startup and cross-device/export workflows.
- Keep raw TURN credentials secret by default and only expose them on explicit
  export/share actions.
- Let future desktop and mobile UX reuse the same typed resource and state
  model.

## Non-Goals
- Replace the normal runtime session model with a resolution-only model.
- Persist exported `generic-turn` secrets indefinitely or hide their expiry.
- Push clipboard, share-sheet, QR, or deep-link implementation details into
  provider packages or transport code.
- Redefine provider-specific browser or WebView policy in this change.

## Decisions

### Decision: Introduce a typed resolution resource separate from sessions

Provider resolution should be represented as a first-class host resource with
its own stable identifier and lifecycle, rather than being smuggled through
runtime session records.

That keeps state semantics honest:

- `resolved` means provider resolution produced transport-ready credentials
- `ready` remains a runtime/session property
- preview-only or post-preview provider outcomes can fail closed before any
  runtime session is claimed to exist

### Decision: Make export explicit and keep ordinary reads redacted

Raw TURN credentials and the full `generic-turn://...` link should not appear
in normal resource reads, event streams, diagnostics bundles, or persisted shell
state.

The host should only return the full handoff secret from an explicit export
action on a successful resolution.
Ordinary reads should surface only redacted or non-secret fields such as:

- provider name
- redacted input
- state
- failing stage/message
- expiry timestamp
- redacted username/password markers when useful for support context

### Decision: Support same-device materialization without mandatory copy/paste

Desktop product validation should not require a user or tester to manually copy
the full `generic-turn://...` link out of the app just to feed it back into the
same host.

The host therefore needs a same-device materialization action that can take a
successful resolution plus operator-managed runtime defaults and create or start
the normal product session path directly.

This is the preferred desktop action for "start on this device".
Explicit export remains available for cross-device handoff, support, and
advanced operator workflows.

### Decision: Exported handoff links expire by time and are not single-use

This change should treat exported `generic-turn://...` handoff links as
time-limited secrets, not single-use tokens.

The host must surface `expires_at` for successful exports and fail closed once
that expiry is reached.
It should not invent a stronger single-use guarantee than the underlying
provider or TURN credential model actually supports.

This keeps the contract honest and practical for:

- retry on the same device before expiry
- short operator handoff windows
- cross-device transfer where the receiving device may need one retry without
  forcing a full live re-resolution

### Decision: Export requires authoritative expiry evidence from the provider result

The host should only allow explicit export when it can attach an authoritative
`expires_at` value derived from provider-backed credential semantics.

If a provider resolution yields transport-ready TURN credentials but does not
surface an authoritative expiry through committed compatibility evidence,
official provider documentation, or a typed repository-owned parser contract,
the host must fail closed for export rather than minting a guessed expiry.

That keeps the contract honest:

- same-device materialization may still be supported for an immediately
  resolved session path
- cross-device export remains gated until expiry semantics are actually known
- the host does not confuse "credential probably short-lived" with "expiry is
  known"

For VK, the repository now has a committed provider-specific parser contract
that derives expiry from TURN REST style usernames and a live proof from April
10, 2026 that confirmed the parser shape against a fresh VK result and a
successful fresh TURN Allocate before the derived boundary.
This change therefore treats VK as an export-capable provider for derived
expiry purposes, while a separate follow-up verification change tracks the
after-boundary live proof step.

### Decision: Resolution results do not become saved profiles by default

This change should not persist provider-resolved secrets into ordinary saved
profiles by default.

The host may materialize a successful resolution into the same-device runtime
path, but that materialization is an operational handoff step, not a new
long-lived credential store.

Explicit export remains the only supported way to obtain the full secret link.
If the product later needs an explicit "save temporary handoff profile" action,
that should be proposed separately with its own persistence and secret-retention
rules.

### Decision: Same-device materialization uses explicit non-secret runtime defaults

Same-device materialization should take a `resolution_id` plus an explicit
non-secret runtime-defaults payload supplied by the caller.

Those defaults own only operator-managed runtime knobs such as:

- local listen address
- peer address
- connection count
- transport mode
- DTLS flag
- bind interface
- log level
- supported TURN host/port overrides when explicitly operator-managed

They do not include provider secrets or the derived `generic-turn` handoff
link, and they do not require the host to save a new profile as a side effect
of materialization.

For this change, the defaults should live with the calling product surface as
non-secret persisted state or deployment configuration, not as a secret-bearing
saved profile in the host contract.

### Decision: Keep the shell contract platform-neutral and push UX details out

Desktop and mobile should consume the same typed resolution resource and the
same export/materialize actions.
Platform-specific UX remains outside the shared contract:

- desktop may offer "start on this device" and optional copy-to-clipboard
- mobile may offer copy/share/QR or later deep-link handoff
- CLI may still expose low-level export output for operator tooling

That split keeps provider and host semantics shared while allowing different
presentation layers per platform.

### Decision: Desktop deep-link intake stays out of scope for this change

Desktop OS-level deep-link registration for invite intake should not be part of
this change.

The supported baseline remains explicit invite entry or paste into the product
surface that consumes the typed resolution contract.
If desktop later adds OS-level invite deep-link registration, it should be a
follow-up on top of this same handoff model rather than a prerequisite for it.

## Alternatives Considered

### Keep using `cmd/probe` as the only export path

Rejected because it leaves desktop/mobile outside the product contract and
forces validation to drop back to CLI-only tooling.

### Attach derived `generic-turn` output directly to runtime sessions

Rejected because it confuses provider resolution with runtime readiness and
makes `ready` ambiguous.

### Store the full secret link in profiles or diagnostics by default

Rejected because it weakens the redaction boundary and increases accidental
secret leakage through support bundles, logs, or persisted GUI state.

## Risks / Trade-offs
- Exported credentials may be very short-lived.
  Mitigation: the host must surface `expires_at` and fail closed after expiry
  instead of pretending a stale link is reusable.
- Some providers may never qualify for cross-device export if they do not
  surface authoritative expiry semantics.
  Mitigation: keep same-device materialization available as the baseline
  product path and gate export per provider/result capability instead of
  weakening the contract.
- A resolution resource adds another lifecycle model beside sessions.
  Mitigation: keep it narrow and typed, with explicit state transitions and
  explicit handoff boundaries.
- Same-device materialization could silently bypass the user-visible handoff
  semantics if designed too loosely.
  Mitigation: require explicit materialize/start actions and keep them mapped to
  the same normal product runtime path used for ordinary `generic-turn`
  sessions.

## Migration Plan
1. Add the typed resolution-handoff capability to the local host contract.
2. Align shared handoff formatting and redaction rules across host and CLI.
3. Update desktop and mobile shells to consume the typed resource and explicit
   export/materialize actions.
4. Update user/operator docs so live-invite validation uses the product path
   instead of an external CLI-only workaround when supported.
