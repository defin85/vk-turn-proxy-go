# Compatibility

This directory will hold:
- fixtures captured from the legacy Go implementation
- integration scenarios for `old -> new` and `new -> old`
- transport-level invariants that define the compatibility contract

The legacy repository `/home/egor/code/vk-turn-proxy` remains the oracle until these scenarios are implemented.

Provider-specific contracts live next to their fixtures.
The first committed contract is `test/compatibility/vk/README.md`, which defines the VK call debug contour and the schema for sanitized fixtures.
Runtime acceptance scaffolding for the supported VK-backed client slice lives in
`test/compatibility/vk/runtime/README.md`.
