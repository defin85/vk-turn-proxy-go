## Context

The earlier Linux flow changes define:

- the packaged host boundary
- the Ubuntu-first ready-path mechanics

They do not yet answer the last product question: when may the repository
honestly advertise `linux_tun` as supported to operators?

That answer depends on a repo-owned install surface, helper placement, and a
documented supported target. Raw local bundles or ad hoc manual root commands do
not satisfy that bar.

## Goals

- Define one honest support-promotion gate for Linux `linux_tun`.
- Keep support target-specific instead of treating one Ubuntu success as all of
  Linux.
- Tie the support claim to a repo-owned install/package surface and validation
  runbook.

## Non-Goals

- General cross-distro package distribution strategy.
- Non-Ubuntu desktop support promotion.
- New runtime engine or carrier families.

## Decisions

### Decision: Support promotion requires a repo-owned install surface

The repository should not advertise `linux_tun` support from a hand-copied home
directory bundle alone. The first promoted support claim must depend on a
repo-owned packaged install surface that places:

- the desktop bundle
- the Linux helper
- the Ubuntu privilege-mediation metadata

### Decision: The first promoted target is Ubuntu packaged desktop only

The runtime and GUI support claims should move from unavailable to supported
only for the documented Ubuntu packaged target. Other Linux targets remain
fail-closed until they have their own verified packaging and startup evidence.

### Decision: GUI and runtime claims move together

The desktop shell should offer `linux_tun` as a supported mode only when the
bundled host and packaged target really satisfy the documented install and
verification bar. The shell should not grow a special optimistic Linux affordance.

## Risks / Trade-offs

- A `.deb`-first or Ubuntu-first path delays broader Linux reach.
- Packaging helper and privilege metadata incorrectly would undermine the entire
  support claim.
- If the package/install entrypoint is weakly specified, support promotion will
  be noisy and subjective.

## Validation Plan

- Strict OpenSpec validation for this change.
- Future implementation must prove package staging, host capability reporting,
  and Ubuntu packaged startup evidence together before support promotion lands.
