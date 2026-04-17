## ADDED Requirements

### Requirement: Authenticated hosted-call contour stays anchored by replayable evidence

The system SHALL keep sanitized, replayable compatibility evidence for the
supported authenticated `https://calls.vk.com/` hosted-call contour separate
from the legacy invite-first VK contour through a distinct authenticated
scenario family and compatibility contract metadata that identify the
authenticated start path and contour family explicitly.

#### Scenario: Authenticated hosted-call contour is replayed from sanitized evidence

- **GIVEN** browser-observed evidence from the approved mobile owned-browser
  authenticated flow includes `auth.anonymLogin` bootstrap data and
  `vchat.startConversation(createJoinLink=true)` responses
- **WHEN** compatibility tests replay that authenticated hosted-call contour
- **THEN** the provider preserves the committed stage ordering, redaction, and
  transport-field extraction expectations for that contour
- **AND** the replay does not force the authenticated hosted-call path through
  the legacy invite-first stage contract

#### Scenario: Authenticated fixture contract is not inferred from filename alone

- **GIVEN** a sanitized compatibility fixture captured from the supported
  authenticated `https://calls.vk.com/` root-start contour
- **WHEN** fixture schema validation or replay tooling classifies that fixture
- **THEN** the compatibility contract identifies it as an authenticated contour
  with a distinct authenticated scenario family such as `vk_call_authenticated_*`
- **AND** that authenticated fixture family is not forced through invite-only
  normalized join-token input rules
