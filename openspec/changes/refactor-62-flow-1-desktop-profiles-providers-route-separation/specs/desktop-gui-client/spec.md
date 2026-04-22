## ADDED Requirements

### Requirement: Desktop GUI shell gives Profiles and Providers distinct top-level workspaces

The system SHALL expose saved profiles and reusable provider records as
separate top-level desktop workspaces instead of mixing them through an
in-canvas section switcher inside one workbench route.

#### Scenario: Operator enters Profiles from the left pad

- **GIVEN** the desktop GUI shell is in its routine task-entry state
- **WHEN** the operator opens the `Profiles` workspace from the left pad or its
  compact-drawer equivalent
- **THEN** the main canvas focuses saved profiles and profile-editing work
- **AND** reusable provider-record browsing, preset bootstrap, and
  provider-family selection do not appear as equal-weight section switches
  inside that `Profiles` route

#### Scenario: Operator enters Providers from the left pad

- **GIVEN** the desktop GUI shell is in its routine task-entry state
- **WHEN** the operator opens the `Providers` workspace from the left pad or
  its compact-drawer equivalent
- **THEN** the main canvas focuses reusable managed-provider records, presets,
  and provider-family workflows
- **AND** saved-profile-specific editing or library actions do not appear as
  equal-weight section switches inside that `Providers` route

#### Scenario: Switching between Profiles and Providers keeps shell-owned workflow context

- **GIVEN** the operator has existing draft or selection state in the desktop
  `Profiles` workspace and in the desktop `Providers` workspace
- **WHEN** they switch between those two workspaces through the left pad or its
  compact-drawer equivalent
- **THEN** the shell restores the relevant workspace route without requiring an
  in-canvas section chip as the primary way to reach the other workspace
- **AND** switching does not discard the active draft or current selection of
  the workspace being left
