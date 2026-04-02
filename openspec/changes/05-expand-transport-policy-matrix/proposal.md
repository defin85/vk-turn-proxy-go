# Change: Expand transport policy matrix

## Why

The first runtime slice should start narrow, but the repository goals explicitly include transport policy control such as DTLS on or off and TURN UDP on or off.
Those policies need their own change because they materially alter startup wiring, error handling, and test coverage.

## What Changes

- Extend the client runtime beyond the first-slice defaults to support additional transport policy combinations.
- Support explicit `mode=tcp|udp|auto`, explicit `dtls=true|false`, and interface pinning where declared by config.
- Replace first-slice unsupported-config rejections with real behavior for the newly supported combinations.
- Add tests and docs that define the supported matrix precisely.

## Impact

- Affected specs: `transport-policy-matrix`
- Related specs: `tunnel-client-runtime`
- Affected code: `internal/config`, `internal/session`, `internal/transport`, `cmd/tunnel-client`, integration tests
