# VK Invite User Workflow

This document defines the canonical product workflow for VK-backed user
sessions.

## Actor model

- an organizer or dispatcher creates the VK call outside the product
- invite sharing stays out-of-band through chat, email, CRM, or another
  operator-owned channel
- the end user consumes that shared `https://vk.com/call/join/...` invite
  inside the product
- peer, TURN, DTLS, and similar transport defaults stay operator-managed in the
  supported flow

## Supported flow

1. the end user pastes a shared VK invite into the product
2. the product starts typed invite resolution
3. if VK requires browser continuation, the operator or user completes that
   step in the browser and clicks `Join`
4. the product reports `resolved` only after provider resolution yields
   transport-ready credentials
5. the runtime may then start from that resolved handoff with the
   operator-managed defaults for the session
6. the product reports `ready` only after transport startup succeeds

## Boundaries

The canonical VK workflow does not claim:

- call creation, rotation, or revocation inside the product
- preview-only browser state as equivalent to `joined`
- raw peer or transport editing as required end-user input

Advanced transport controls and direct saved-profile startup remain available
for support, debugging, and compatibility work, but they are outside the normal
end-user VK invite path.
