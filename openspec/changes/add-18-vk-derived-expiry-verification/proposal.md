# Change: [18] Add VK derived expiry verification

## Why
The repository now derives VK TURN credential expiry from TURN REST style
usernames and has a live proof that a fresh Allocate succeeds before the
derived boundary.

That is strong evidence, but the repository still benefits from one explicit
post-expiry verification step so release decisions do not rely on pre-boundary
evidence alone.

## Sequence
- Order: `18`
- Depends on: `add-17-provider-resolution-handoff`
- Unblocks: release confidence for VK export expiry gating

## What Changes
- Add one small repo-owned verification workflow for VK derived expiry.
- Define the acceptance contract for a pre-expiry success check and a
  post-expiry failure check using `cmd/turn-expiry-check`.
- Keep stored evidence redacted so the workflow does not persist reusable live
  `generic-turn://...` secrets.

## Impact
- Affected specs: `vk-derived-expiry-verification` (new)
- Affected code: docs and operator verification workflow around
  `cmd/turn-expiry-check`
