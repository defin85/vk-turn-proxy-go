## 1. Contract
- [x] 1.1 Add the `provider-resolution-handoff` capability with typed
      resolution states, explicit challenge handling, explicit export
      semantics, and same-device materialization semantics
- [x] 1.2 Define the redaction boundary so ordinary resolution reads, events,
      diagnostics, and persisted shell state do not expose raw TURN credentials
      or the full `generic-turn://...` link by default

## 2. Host and CLI
- [x] 2.1 Add local host APIs for creating, inspecting, continuing, cancelling,
      exporting, and expiring provider resolution records separately from
      runtime sessions
- [x] 2.2 Add a host action that materializes a successful resolution into the
      supported same-device product path from an explicit non-secret
      runtime-defaults payload without requiring manual copy/paste of the full
      secret link or persistence of a secret-bearing profile
- [x] 2.3 Align CLI/provider tooling so `cmd/probe` and the local host use the
      same repository-owned `generic-turn` handoff formatting and redaction
      rules
- [x] 2.4 Gate explicit export on authoritative provider expiry evidence and
      fail closed when a resolution is transport-ready but expiry remains
      unknown, including support for repository-owned provider-specific parser
      contracts such as VK TURN REST username derivation

## 3. Product Surfaces
- [x] 3.1 Update the desktop shell to consume the typed resolution resource and
      support the product path `invite -> browser continuation if needed ->
      resolved -> start on this device`
- [x] 3.2 Update the mobile shell to consume the same typed resolution resource
      and support explicit copy/share handoff actions for another device
- [x] 3.3 Keep platform-specific clipboard, QR, share-sheet, and deep-link
      behavior in thin platform adapters rather than in provider or shared
      runtime packages

## 4. Verification
- [x] 4.1 Add host/control-plane coverage for successful resolution, challenge
      continuation, explicit export, same-device materialization, authoritative
      expiry gating, derived-expiry providers such as VK, expiry, and
      redaction behavior
- [x] 4.2 Add or update desktop/mobile shell coverage for the typed resolution
      workflow, explicit export actions, and non-secret runtime-defaults
      persistence
- [x] 4.3 Run the smallest relevant verification set, then `go test ./...`,
      `go build ./...`, and the relevant Flutter analyze/test workflows
