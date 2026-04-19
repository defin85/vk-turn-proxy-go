## MODIFIED Requirements

### Requirement: Owned mobile WebView continuation preserves app-owned session boundaries

The system SHALL keep embedded continuation state inside app-managed WebView
storage, may reuse that app-owned browser state across later owned-browser
continuations only when the product explicitly marks those flows as compatible
with remembered embedded sign-in on the same mobile install, and must not
import session state from the user's external browser profile.

#### Scenario: Embedded continuation keeps browser state inside the app sandbox

- **GIVEN** a mobile challenge that runs through an owned in-app WebView
- **WHEN** provider continuation needs cookies, storage, or other
  browser-backed state from that flow
- **THEN** the runtime uses the app-owned embedded session state for that
  continuation
- **AND** it does not read cookies or profile data from the user's regular
  browser installation

#### Scenario: Later owned-browser challenge reuses remembered app-owned sign-in

- **GIVEN** a prior compatible mobile owned-browser flow already established
  valid app-owned browser cookies or storage on the same install
- **AND** the later owned-browser challenge is also explicitly approved for
  remembered embedded sign-in reuse
- **WHEN** the operator opens that later challenge
- **THEN** the mobile shell may reuse that remembered app-owned browser state
- **AND** it does not force a fresh login solely because the previous embedded
  challenge route was closed

#### Scenario: Unapproved owned-browser flow does not inherit remembered reuse

- **GIVEN** the mobile shell has remembered app-owned browser state from a
  prior compatible owned-browser flow
- **AND** a later owned-browser challenge is not explicitly approved for
  remembered embedded sign-in reuse
- **WHEN** the operator opens that later challenge
- **THEN** the shell does not treat remembered reuse as enabled solely because
  the provider name or generic owned-browser mode matches

## ADDED Requirements

### Requirement: Remembered mobile owned-browser sign-in is explicit and resettable

The system SHALL provide an explicit operator path to clear remembered
app-owned browser sign-in state without wiping unrelated mobile shell state.
For this first slice, that reset MAY target the product-global app-owned
browser sandbox used by compatible owned-browser continuations on the install.

#### Scenario: Operator forgets remembered embedded sign-in

- **GIVEN** the mobile shell has remembered app-owned browser state for owned
  in-app continuation
- **WHEN** the operator chooses to forget or reset that embedded sign-in
- **THEN** the shell clears the app-owned browser session state used for those
  continuations, including cookies and other browser-backed storage required by
  the remembered sign-in session
- **AND** the next compatible owned-browser challenge starts from signed-out
  embedded browser state
- **AND** the shell does not wipe saved profiles, provider drafts, or unrelated
  local shell preferences
