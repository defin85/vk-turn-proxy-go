## ADDED Requirements

### Requirement: Authenticated `calls.vk.com` start is an additive VK session input

The system SHALL treat the supported `https://calls.vk.com/` start link as an
additional VK session-start path on approved owned-browser surfaces without
removing the existing `https://vk.com/call/join/...` invite workflow.

#### Scenario: Mobile starts a VK session from `calls.vk.com`

- **GIVEN** the current mobile build approves the VK app-owned browser path
- **AND** the operator starts from the supported `https://calls.vk.com/` link
- **WHEN** the VK provider flow begins
- **THEN** the product accepts that start link as a supported VK input for the
  authenticated hosted-call flow
- **AND** it does not require the operator to paste a `vk.com/call/join/...`
  link for that specific flow

### Requirement: Authenticated hosted-call contour resolves transport-ready data

The system SHALL resolve the authenticated VK hosted-call flow from the
provider-observed `auth.anonymLogin` bootstrap plus
`vchat.startConversation(createJoinLink=true)` responses instead of forcing the
flow through the legacy invite contour.

#### Scenario: Hosted call yields transport-ready TURN data

- **GIVEN** the operator authenticated inside the approved app-owned VK browser
- **AND** the same browser session reaches the provider-owned hosted-call flow
- **WHEN** the observed responses include `auth.anonymLogin` followed by
  `vchat.startConversation(createJoinLink=true)` with transport-ready fields
- **THEN** the provider resolves normalized transport-ready data from that
  hosted-call response
- **AND** it may surface the result through the existing typed runtime artifact
  contract

#### Scenario: Authenticated flow stops before transport-ready data

- **GIVEN** the operator authenticated inside the approved app-owned VK browser
- **WHEN** the observed authenticated contour never yields transport-ready
  hosted-call fields such as `turn_server`
- **THEN** provider resolution fails explicitly
- **AND** it does not pretend that authenticated browser state alone implies a
  resolved artifact

### Requirement: Authenticated VK hosted-call creation stays provider-owned

The system SHALL keep VK account auth and hosted-call creation inside the
provider-owned browser UI for the authenticated `calls.vk.com` flow.

#### Scenario: Product does not synthesize call creation outside VK UI

- **GIVEN** the operator starts from the supported `https://calls.vk.com/`
  path
- **WHEN** the flow requires account auth, opening a room, or creating a new
  hosted call
- **THEN** the operator completes those steps inside the approved VK browser UI
- **AND** the product does not create or mutate VK calls through undocumented
  out-of-band API calls outside that UI
