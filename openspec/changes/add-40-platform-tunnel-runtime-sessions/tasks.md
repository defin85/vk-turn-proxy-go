## 1. Contract
- [x] 1.1 Define the control-plane rule that a runtime-backed platform tunnel
  ready path publishes an ordinary typed session record instead of leaving
  runtime lifecycle visible only through tunnel state.
- [x] 1.2 Define stable correlation for that runtime-backed startup, including
  session linkage to `source_resolution_id` and a ready-result session
  identifier for shells.
- [x] 1.3 Clarify that same-device startup from a resolved artifact still uses
  the same ordinary session surface even when the underlying runtime path is a
  packaged platform tunnel.

## 2. Host and Control Plane
- [x] 2.1 Extend the platform-tunnel start or resume result and host internals
  so a `ready=true` runtime-backed startup creates or publishes the canonical
  runtime session record.
- [x] 2.2 Keep platform-tunnel lifecycle ownership inside the packaged host
  boundary while reusing the canonical control-plane session path instead of
  inventing a second tunnel-only runtime record type.
- [x] 2.3 Add fail-closed state handling so permission, route-validation, host
  bring-up, or runtime-attach failure does not leave behind a misleading active
  session for that startup attempt.

## 3. Mobile Shell
- [x] 3.1 Refresh activity surfaces after successful platform-tunnel start or
  resume and select the resulting runtime session when the control plane
  returns one.
- [x] 3.2 Surface VPN-backed runtime through the existing `Sessions` activity
  workflow, including stop and diagnostics affordances, rather than a separate
  tunnel-only runtime list.

## 4. Verification
- [x] 4.1 Add Go coverage for session publication, `session_id` correlation,
  and cleanup semantics across platform-tunnel success and failure paths.
- [x] 4.2 Add or update Flutter coverage for the mobile activity surface so a
  ready platform tunnel produces the corresponding `Sessions` entry.
- [x] 4.3 Validate the mobile Android flow on a physical device or emulator:
  active VPN-backed runtime, `Resolutions` provenance, and matching
  `Sessions` entry all stay coherent.
- [x] 4.4 Run `openspec validate add-40-platform-tunnel-runtime-sessions --strict --no-interactive`.
