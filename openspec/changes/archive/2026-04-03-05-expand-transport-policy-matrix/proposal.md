# Change: Expand transport policy matrix

## Why

The first runtime slice should start narrow, but the repository goals explicitly include transport policy control such as DTLS on or off and TURN UDP on or off.
Those policies need their own change because they materially alter startup wiring, error handling, and test coverage.

## What Changes

- Modify the canonical `tunnel-client-runtime` contract to expand the supported one-session transport policy matrix beyond the first slice.
- Support explicit TURN transport selection `mode=udp|tcp|auto`, explicit `dtls=true|false`, and a narrowly defined outbound bind target contract.
- Keep local client listening on UDP in every supported combination while varying TURN transport and peer relay setup explicitly.
- Replace first-slice unsupported-config rejections with real behavior only for the newly documented combinations.
- Refresh compatibility evidence and docs for every VK-backed runtime combination that this change claims as supported.

## Impact

- Affected specs: `tunnel-client-runtime`
- Related specs: `vk-runtime-compatibility`
- Affected code: `internal/config`, `internal/session`, `internal/transport`, `cmd/tunnel-client`, `test/turnlab`, `test/compatibility/vk/runtime`
