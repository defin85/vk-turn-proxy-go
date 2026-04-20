## MODIFIED Requirements

### Requirement: VK-backed user sessions start from a shared invite link

The system SHALL treat a standard `https://vk.com/call/join/...` invite link as
the supported VK session input for end users while keeping VK call creation and
invite distribution outside the product.

#### Scenario: Organizer shares a VK invite with an end user

- **GIVEN** an organizer creates a regular VK call in VK and obtains a join
  link
- **WHEN** that link is shared with an end user through chat, email, CRM, or
  another out-of-band channel
- **THEN** the product accepts the shared invite link as the VK session input
- **AND** the product does not require the end user to create or manage the
  call inside the product

#### Scenario: End user supplies a self-created VK invite

- **GIVEN** an end user independently obtains a valid VK invite link
- **WHEN** the user starts the supported VK workflow
- **THEN** the same invite-intake path is used
- **AND** the runtime contract does not change based on who originally created
  the call

#### Scenario: Authenticated `calls.vk.com` support does not remove invite intake

- **GIVEN** the product also supports an authenticated VK start path from
  `https://calls.vk.com/`
- **WHEN** an operator or end user still supplies a valid
  `https://vk.com/call/join/...` invite link
- **THEN** the existing invite-first VK path remains supported
- **AND** the product does not require the authenticated `calls.vk.com` flow
  for that invite
