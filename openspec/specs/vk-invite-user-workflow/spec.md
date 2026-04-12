# vk-invite-user-workflow Specification

## Purpose
TBD - created by archiving change add-10-vk-invite-user-workflow. Update Purpose after archive.
## Requirements
### Requirement: VK-backed user sessions start from a shared invite link

The system SHALL treat a standard `https://vk.com/call/join/...` invite link as the supported VK session input for end users while keeping VK call creation and invite distribution outside the product.

#### Scenario: Organizer shares a VK invite with an end user

- **GIVEN** an organizer creates a regular VK call in VK and obtains a join link
- **WHEN** that link is shared with an end user through chat, email, CRM, or another out-of-band channel
- **THEN** the product accepts the shared invite link as the VK session input
- **AND** the product does not require the end user to create or manage the call inside the product

#### Scenario: End user supplies a self-created VK invite

- **GIVEN** an end user independently obtains a valid VK invite link
- **WHEN** the user starts the supported VK workflow
- **THEN** the same invite-intake path is used
- **AND** the runtime contract does not change based on who originally created the call

### Requirement: Supported VK invite workflow separates end-user input from operator-managed transport defaults

The system SHALL separate the user-facing VK invite input from operator-managed peer and transport settings for the supported workflow.

#### Scenario: Managed deployment starts a VK session

- **GIVEN** a deployment with operator-managed peer address, local listen policy, and transport defaults
- **WHEN** an end user starts a VK-backed session
- **THEN** the end user only has to provide the VK invite link and initiate startup
- **AND** the supported workflow does not require the end user to edit raw peer, TURN, or DTLS settings

#### Scenario: Advanced transport controls remain outside the standard path

- **GIVEN** a development or support environment that exposes raw transport fields
- **WHEN** an operator uses those advanced controls
- **THEN** those controls remain separate from the standard VK invite workflow
- **AND** the product does not redefine them as required end-user inputs

### Requirement: Browser-mediated join gates VK session readiness

The system SHALL guide the user through browser continuation and only report session readiness after the user progresses beyond the preview or `Join` boundary and supported transport startup succeeds.

#### Scenario: Invite reaches preview before join

- **GIVEN** a valid VK invite whose controlled browser flow reaches the pre-join preview UI
- **WHEN** provider resolution requires the user to continue in the browser
- **THEN** the product instructs the user to continue in the browser and click `Join`
- **AND** it does not report the session as ready while the flow remains preview-only

#### Scenario: Session becomes ready after join

- **GIVEN** the user has progressed beyond preview in the browser
- **WHEN** provider resolution yields normalized TURN credentials and the supported transport startup succeeds
- **THEN** the product reports session readiness through the supported runtime surface
- **AND** the local runtime starts with the operator-managed defaults associated with that session

#### Scenario: Post-browser transport startup fails

- **GIVEN** the user completed the browser flow past preview
- **WHEN** the runtime fails during `turn_allocate`, `peer_setup`, `dtls_handshake`, or another documented startup stage
- **THEN** the product reports a stage-aware failure instead of implying a successful join
- **AND** diagnostics remain available through the supported support surface without exposing raw live-browser secrets

