## Context

The archived debug contour change already anchored provider resolution to explicit VK evidence.
The next gap is runtime behavior after provider resolution: even if the Go runtime works locally, it still needs an auditable claim about where it matches or intentionally diverges from the legacy client.

## Goals

- Define explicit runtime compatibility scenarios for the supported VK client slice.
- Keep acceptance assets redacted and replayable where feasible.
- Make intentional gaps versus legacy behavior explicit instead of implied.

## Non-Goals

- Claiming parity for unsupported transport policies or multi-connection behavior before those changes land.
- Depending on live VK acceptance in CI.
- Replacing deterministic local integration tests.

## Decisions

- Keep runtime compatibility assets separate from product code under `test/compatibility/...`.
- Cover at least one successful VK-backed startup/forwarding scenario and one explicit runtime failure scenario for the supported slice.
- Allow manual live acceptance notes for VK when CI-safe replay assets are not enough, but redact invite and credential material.
- Document unsupported legacy behaviors as explicit deviations instead of silently inheriting them.

## Risks / Trade-offs

- Runtime compatibility is harder to replay than provider-only parsing.
  Mitigation: pair deterministic local harnesses with redacted manual evidence and narrow the supported slice.
- Live acceptance may drift as VK changes.
  Mitigation: keep CI independent from live VK and refresh acceptance notes when supported behavior changes.

## Migration Plan

1. Define runtime compatibility scenarios and acceptance asset format.
2. Capture the first redacted evidence set for the supported slice.
3. Add compatibility checks and docs for known deviations.
