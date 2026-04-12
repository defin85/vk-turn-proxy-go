## Context
The repository already has a useful first generation of provider abstraction:

- a provider registry
- typed local-host challenges
- typed resolution records
- explicit `generic-turn://...` export and same-device materialization for
  transport-ready TURN credentials

That model works for VK and the deterministic `generic-turn` path because both
end in the same artifact family: short-lived TURN credentials that feed the
existing tunnel runtime.

It breaks down for the next provider wave.

Live provider research from April 11, 2026 showed:

- `WB Stream` room pages issue room-scoped media tokens and chat tokens, then
  enter a conference runtime that uses provider-owned signaling and media
  infrastructure
- `Ростелеком Умный дом` camera pages issue stream/player tokens and choose
  between HLS-style and fMP4-over-WebSocket player paths, with archive and
  event-timeline semantics that do not match a conference room

Those are both valid provider-backed products, but they are not both honest
fits for a `generic-turn` handoff contract.

## Goals
- Keep one universal provider-facing contract at the host and shell layers.
- Allow more than one runtime family without forcing fake TURN semantics onto
  every provider.
- Make shell UX descriptor-driven and capability-driven instead of
  provider-string-driven.
- Make provider auth requirements and browser policy explicit so shells do not
  guess whether embedded WebView, external browser, guest auth, or account auth
  are valid for a given provider.
- Preserve the current explicit redaction and fail-closed rules.
- Keep provider-specific transport and player details out of generic shell code.

## Non-Goals
- Implement `WB Stream` or `smarthome` adapters in this change.
- Replace the existing tunnel runtime with conference or camera playback code.
- Guarantee that every provider family supports cross-device export.
- Hide the difference between conference-style and camera-style product
  surfaces when that difference is user-visible and real.

## Decisions

### Decision: Introduce provider descriptors as a first-class host resource

The host should expose a typed provider catalog so shells can ask:

- which providers exist
- what input shape each provider expects
- whether the provider requires account auth, guest auth, or both
- whether browser continuation must use an external browser or may use an
  embedded surface
- which challenge modes may appear
- which artifact families the provider may resolve into
- which post-resolution actions are even meaningful

That removes the need for shells to infer workflow from `provider == "vk"` or
similar string checks.

### Decision: Multi-provider discovery is gated by an explicit host capability

The add-20 contract is additive to the repository overall, but not something a
new shell should infer from the old `provider-resolution-handoff` capability or
from `contract_version == 1` alone.

Updated shells need a machine-checkable way to reject older hosts before they
try to render descriptor-driven entry or artifact-family actions.

The host therefore needs to advertise a distinct capability for the
multi-provider catalog/artifact surface, and updated shells should require that
capability during negotiation before enabling add-20 UX.

This keeps compatibility honest during rollout:

- old hosts can remain handoff-only
- updated shells fail closed instead of assuming catalog support
- the repository does not need to overload the meaning of the existing
  handoff-only capability

### Decision: Roll out add-20 additively, then remove the legacy handoff path

This change was rolled out additively for first-party shell migration, but the
shipped add-20 surface is not a permanent dual-contract state.

Updated shells negotiate the new capability and use it preferentially; they
must not silently fall back to the legacy handoff-only model for
descriptor-driven or artifact-family-specific UX.

The delivered end state of the rollout removes the legacy handoff path once:

- desktop and mobile first-party shells no longer depend on it
- verification coverage has moved to the add-20 contract
- no supported runtime family still requires the old TURN-only resolution model

### Decision: Authorization and browser policy are provider-level contract fields

Some providers are not just "different artifacts"; they also have different
entry constraints.

The descriptor therefore needs explicit contract fields for at least:

- auth posture
- continuation policy
- browser policy

Examples:

- `vk` may continue to support invite-first flows with browser continuation
- `WB Stream` may require either guest or account auth and may need a real
  external browser flow when anti-bot or fingerprint policy makes embedded
  surfaces unreliable
- `smarthome` may require an authenticated account/device context before any
  camera artifact is even resolvable

These constraints belong in the host-reported descriptor, not in shell
hard-coding.

### Decision: Generalize resolution output into typed artifact families

A successful provider resolution should yield a typed artifact family rather
than an implicit promise that every provider becomes a `generic-turn` handoff.

The baseline artifact families for this change are:

- `generic_turn`
- `conference_room`
- `camera_stream`

The contract must allow more families later without forcing a redesign of the
host or shells.

### Decision: Keep family-specific executors separate from generic resolution

Provider resolution and same-device execution remain separate concerns.

The host should:

- resolve provider input into a typed artifact record
- report which actions are supported for that artifact
- materialize or start a same-device path only when a family-specific executor
  exists for the requested action

This preserves the useful `resolution != session` boundary from the current
handoff model.

### Decision: Keep `generic-turn` export as one family capability, not the universal contract

Explicit `generic-turn://...` export remains valid for `generic_turn` artifacts
that have authoritative expiry semantics.

Conference-room and camera-stream artifacts must not pretend they can always be
flattened into `generic-turn` output just to satisfy an old API shape.

If a future provider can legitimately produce both a conference artifact and a
transport-ready TURN handoff, the host may expose both as explicit
capabilities, but it must not synthesize one from the other.

### Decision: Ordinary reads stay redacted across all families

The current redaction rule stays in force, but now applies to more than TURN
credentials.

Ordinary resource reads, events, and diagnostics must not expose:

- raw TURN usernames/passwords
- room-scoped media tokens
- chat tokens
- camera stream tokens
- cookie/bootstrap tokens

Only explicit export or family-specific operator actions may return full secret
artifacts, and only when the family contract explicitly allows that.

### Decision: Shell actions are capability-driven, not provider-driven

After resolution, shells should render actions from host-reported capabilities,
for example:

- `start_on_this_device`
- `export_handoff`
- `open_room`
- `open_camera`
- `open_archive`

This lets one shell stay honest across very different providers.

Those actions must be exposed as stable machine-readable identifiers plus typed
availability metadata, not as display-only labels.
That keeps platform presentation separate from the shared contract:

- the host defines what action exists and whether it is currently supported
- desktop/mobile choose labels, icons, grouping, and copy
- shells do not need to recover action meaning from localized strings

Action metadata should also report execution ownership:

- `host` for actions that mutate runtime/provider state or reveal secret-bearing
  payloads
- `shell_local` for purely local affordances such as copy/share over an already
  exported payload
- `shell_external` for opening a browser, room, camera, or archive target using
  a host-provided non-secret navigation target

For this change, actions like `open_room`, `open_camera`, and `open_archive`
should default to `shell_external` unless and until a family-specific local
executor is implemented in the host.

Examples:

- a `generic_turn` artifact may support `start_on_this_device` and
  `export_handoff`
- a `conference_room` artifact may support `open_room` and later
  `start_on_this_device` only if a conference executor exists
- a `camera_stream` artifact may support `open_camera` or archive-related
  actions without claiming tunnel startup support

Entry and continuation UX should follow the same rule:

- descriptors drive whether the shell offers guest auth, account auth, or both
- descriptors drive whether the shell uses an embedded surface or an external
  browser for continuation
- shells must not silently downgrade an external-browser-required provider into
  an embedded WebView flow

### Decision: Unsupported actions fail closed with stage-aware errors

If a shell requests an action that the resolved artifact family does not
support, or that the current host build cannot execute, the host must fail
explicitly and keep the resolution/session boundary honest.

That prevents the GUI from claiming "ready" or "started" for a provider family
that the local build cannot actually execute.

### Decision: Provider entry uses a typed input envelope

The long-term add-20 contract should not assume that every provider starts from
one opaque `link` string.

Provider descriptors already declare the expected input kind, so the start
resolution request should evolve to a typed input envelope that carries:

- the selected provider identifier
- the declared input kind
- the operator-supplied value or structured fields for that kind

The shipped add-20 host requires that typed envelope and no longer accepts the
legacy `provider + link` request shape as a compatibility bridge.

### Decision: Persisted shell state migrates through descriptors, not resolved artifacts

Persisted desktop/mobile state should continue to store only non-secret
operator-managed data:

- selected provider
- non-secret draft input
- runtime defaults and local presentation state

It must not persist resolved artifact payloads, action results, or other
provider secrets.

Legacy saved drafts should be migrated lazily:

- if a legacy draft maps cleanly onto a descriptor-declared input kind, the
  shell upgrades it in place
- if it does not map cleanly, the shell marks it as legacy/incomplete and asks
  the operator to re-enter the provider input

This keeps migration explicit without blocking rollout on a one-shot state
conversion script.

## Alternatives Considered

### Keep the current generic-turn-only handoff model and special-case new providers in shells

Rejected because it would duplicate provider logic across the host, desktop,
and mobile surfaces and make each new provider more expensive than the last.

### Treat every new provider as a new top-level product with unrelated UX and APIs

Rejected because the repository still needs one universal local host contract
for discovery, resolution, challenge continuation, and capability negotiation.

### Hide family differences behind one fake "session start" action

Rejected because conference and camera providers do not share the same runtime
or operator expectations, and pretending otherwise would create misleading UI
and incorrect API claims.

## Risks / Trade-offs
- The model becomes broader than the current TURN-only handoff contract.
  Mitigation: keep the family list explicit, keep actions capability-gated, and
  keep resolution separate from execution.
- Some providers may expose multiple artifact families or evolve over time.
  Mitigation: descriptors report possible families and actions explicitly rather
  than relying on hard-coded assumptions.
- Some providers may work only with specific browser surfaces because of auth,
  anti-bot, or fingerprint constraints.
  Mitigation: model browser policy explicitly and keep shells fail-closed when
  the required browser surface is unavailable.
- Shell UX can become overly abstract if every family is forced into one visual
  template.
  Mitigation: keep the contract shared, but let desktop/mobile render
  family-specific action groups and explanatory copy.
- Follow-on executors may arrive at different times on different platforms.
  Mitigation: shells must consume host capabilities and remain fail-closed when
  a family is discoverable but not locally executable.

## Migration Plan
1. Add the typed provider descriptor and artifact-family contract.
2. Add the explicit host capability that advertises the multi-provider
   catalog/artifact surface so updated shells can negotiate it directly.
3. Update the local host API to expose provider catalog data plus
   family-capability resolution records, typed input envelopes, stable action
   identifiers, and action execution ownership.
4. Update desktop and mobile shells to render provider entry and post-resolution
   actions from the host descriptors and capabilities, and to stop depending on
   VK-specific or TURN-only branches.
5. Migrate first-party verification and persisted shell state handling to the
   add-20 contract, then remove the legacy `provider-resolution-handoff`
   capability and dead handoff-only branches.
6. Add follow-on provider adapters and family-specific executors one by one,
   starting with the best-supported target family per platform.
