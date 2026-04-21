## ADDED Requirements

### Requirement: Intentional mobile WebView system credential integration is explicit and optional

The system SHALL treat Android system credential integration inside an owned
mobile `WebView` as a separate optional capability rather than as an implicit
part of app-owned embedded sign-in memory or ambient autofill behavior.

#### Scenario: Approved Android owned-browser flow enables explicit system credential support

- **GIVEN** an Android owned-browser flow that the product explicitly approves
  for intentional system credential integration
- **AND** the documented platform and relying-party prerequisites are satisfied
- **WHEN** the operator reaches that approved challenge inside the embedded
  `WebView`
- **THEN** the shell MAY enable the documented Android system credential path
- **AND** it keeps that capability separate from ordinary app-owned cookie or
  storage reuse

#### Scenario: Unapproved flow does not inherit support from ambient hints

- **GIVEN** an Android owned-browser flow that is not explicitly approved for
  intentional system credential integration
- **WHEN** autofill or password-manager suggestions appear incidentally inside
  the `WebView`
- **THEN** the shell does not claim intentional system credential support for
  that flow
- **AND** it does not require those ambient hints for provider continuation

### Requirement: Intentional system credential integration requires documented prerequisites

The system SHALL fail closed for intentional system credential integration
unless the documented Android `Credential Manager` or `WebView` prerequisites,
the required app-to-site trust binding, and the relying-party web support are
all present for that flow.

#### Scenario: Documented prerequisites are satisfied

- **GIVEN** the Android app and embedded `WebView` expose the documented system
  credential integration support
- **AND** the relying-party site exposes the required web credential
  integration and trust association for that app
- **WHEN** the shell enables intentional system credential integration
- **THEN** it uses that documented path instead of password scraping,
  credential import from the external browser, or other ad-hoc heuristics

#### Scenario: Missing prerequisite keeps baseline owned-browser path

- **GIVEN** one or more documented prerequisites are missing, such as absent
  platform support, missing app-to-site trust association, or missing
  relying-party web support
- **WHEN** the operator opens the owned-browser challenge
- **THEN** the shell keeps the baseline owned-browser continuation path without
  claiming intentional system credential support
- **AND** it does not silently degrade into a pseudo-supported mode

### Requirement: Embedded-session reset remains separate from provider-held system credentials

The system SHALL keep app-owned embedded browser reset semantics separate from
credentials that remain held by Android system credential providers.

#### Scenario: Operator clears embedded sign-in after a flow used explicit system credentials

- **GIVEN** a prior Android owned-browser flow used intentional system
  credential integration and also established app-owned embedded browser state
- **WHEN** the operator clears remembered embedded sign-in from the shell
- **THEN** the shell clears only app-owned embedded browser state within its
  documented reset scope
- **AND** it does not claim to delete passwords, passkeys, or other
  provider-held credentials stored by Android credential providers
