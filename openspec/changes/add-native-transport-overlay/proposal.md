# Change: Add native transport overlay

## Why
The canonical repository can already carry arbitrary higher-level traffic only when an external UDP-based overlay such as WireGuard sits above it.
The repository itself still exposes a UDP local ingress on the client and a UDP upstream egress on the server, which blocks direct native TCP or proxy-style transport use inside the canonical implementation.

## What Changes
- Introduce an adapter-based native transport overlay above the existing provider-backed TURN/DTLS/plain underlay.
- Preserve the current UDP path as the reference adapter pair while defining first-class stream semantics for future native TCP and proxy adapters.
- Add explicit policy gating, lifecycle, cleanup, and compatibility-evidence requirements so new adapters fail closed instead of silently degrading into the current UDP-only slice.

## Impact
- Affected specs: `tunnel-client-runtime`, `native-transport-overlay`
- Affected code: `cmd/tunnel-client`, `cmd/tunnel-server`, `internal/session`, `internal/transport`, `internal/tunnelserver`, future adapter packages, integration/compatibility docs and tests
