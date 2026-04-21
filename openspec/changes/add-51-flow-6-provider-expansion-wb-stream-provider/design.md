## Context

`WB Stream` is the first concrete conference-style provider candidate beyond
VK. The repository needs one provider-specific contract that can sit on top of
the generic `conference_room` family without turning the shells back into
provider-name-specific workflow code.

## Goals

- Define the first provider-specific contract for `wb-stream`.
- Keep the output mapped to `conference_room` plus the committed action
  surface.
- Keep browser and auth posture explicit.

## Non-Goals

- Add local conference execution.
- Flatten WB-specific room access into `generic_turn`.
- Claim embedded-browser support unless a later provider-approved change does
  so explicitly.

## Decisions

### Decision: WB resolution ends in `conference_room`

Successful WB resolution maps to the committed `conference_room` artifact
family and its action surface rather than to tunnel semantics.

### Decision: Auth and browser posture stay explicit

The descriptor must state the committed entry posture for WB rather than
leaving shells to guess whether guest entry, account entry, embedded browser,
or external browser is valid.

### Decision: Ordinary reads stay redacted

Room, media, chat, or bootstrap secrets remain redacted in ordinary reads and
only the non-secret action surface is exposed.
