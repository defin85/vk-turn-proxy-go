## Context

The generic multi-provider contract already makes room for conference-style
artifacts, and flow-6 now proposes a generic `conference_room` action surface.
What is still missing is a Telemost-specific provider contract that sits on top
of those generic pieces.

That contract must be honest about three things:

- Telemost is not a `generic_turn` handoff
- ordinary Telemost support can exist before same-device runtime attach exists
- auth and browser posture may be stricter than a generic conference URL flow

## Goals

- Define a stable provider contract for `yandex-telemost`.
- Keep the ordinary resolved artifact mapped to `conference_room`.
- Make auth and continuation posture explicit instead of provider-name-driven.

## Non-Goals

- Implement repo-owned Telemost runtime traffic.
- Claim local conference execution.
- Flatten Telemost room access into `generic_turn`.

## Decisions

### Decision: Telemost resolution ends in `conference_room`

The first reviewed Telemost provider slice should resolve into the committed
`conference_room` family with the ordinary `open_room` action surface.

### Decision: Telemost auth posture stays split and explicit

The descriptor must describe Telemost entry truthfully. If room creation,
room join, or same-device attach have different prerequisites, those
differences belong in the contract instead of shell heuristics.

### Decision: Same-device Telemost execution is separately gated

The provider contract may later coexist with a same-device Telemost carrier,
but it must not imply that such execution already exists.
