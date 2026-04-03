# Change: Add VK runtime compatibility evidence

## Why

Once a supported runtime slice exists, the rewrite still needs explicit evidence that its VK-backed behavior matches the legacy oracle where claimed.
Without runtime-level compatibility assets, future changes will drift on startup semantics, forwarding behavior, or failure handling without a stable reference point.

## What Changes

- Define runtime compatibility scenarios for the supported VK-backed client slice.
- Capture redacted acceptance assets and expected outcomes relative to the legacy repository.
- Add compatibility tests and/or verification tooling that assert supported runtime behavior against those assets.
- Document known intentional deviations from the legacy client where the rewrite is narrower by design.

## Impact

- Affected specs: `vk-runtime-compatibility`
- Related specs: `vk-call-debug-contour`, `tunnel-client-runtime`
- Affected code: `test/compatibility`, runtime acceptance tooling, docs
