## MODIFIED Requirements
### Requirement: Desktop GUI shell presents a workflow-first workspace

The system SHALL present the desktop GUI shell as a single-path workflow
workspace where one current operator task owns the first screen and secondary
libraries move behind explicit task-switch surfaces.

#### Scenario: Shell opens into one active task with no active runtime work

- **GIVEN** the desktop GUI shell opens with no active resolutions or sessions
- **WHEN** the operator lands on the main screen
- **THEN** the shell presents one dominant workflow editor for the current task
- **AND** it does not co-render full saved-profile, managed-provider, and
  preset-browsing libraries around that first read
- **AND** empty diagnostics and live-work surfaces do not occupy a persistent
  dominant region

#### Scenario: Operator opens a secondary library intentionally

- **GIVEN** the operator is working in the active desktop workflow
- **WHEN** the operator invokes an explicit action to browse saved profiles,
  managed providers, presets, or provider families
- **THEN** the shell opens that library through a dedicated secondary surface
  such as a drawer, modal, sheet, or workflow step
- **AND** the shell does not require that library to remain permanently visible
  beside the active editor

#### Scenario: Operator returns from a secondary library without losing work

- **GIVEN** the operator has an in-progress draft, selection, or support
  context in the active desktop workflow
- **WHEN** the operator closes or completes the secondary library surface
- **THEN** the shell returns the operator to the active workflow
- **AND** it preserves the current draft, selection, and relevant support
  context instead of resetting the workflow

## REMOVED Requirements
### Requirement: Desktop GUI offers preset profile bootstrap cards
**Reason**: The desktop shell should no longer promise always-visible preset
cards on the default screen. Preset bootstrap remains available, but it moves
behind an explicit task-start surface.
**Migration**: Use an explicit `new from preset` or equivalent task-start
surface instead of relying on a permanently visible preset rail in the default
desktop layout.

## ADDED Requirements
### Requirement: Desktop GUI shell keeps secondary libraries off the default screen

The system SHALL keep full saved-profile, managed-provider, preset, and
provider-family libraries off the default desktop first read unless the
operator explicitly opens them.

#### Scenario: Default desktop first read stays within one task

- **GIVEN** the desktop GUI shell is in a routine ready state
- **WHEN** the operator views the default first screen
- **THEN** the shell shows only the active task, compact readiness, and minimal
  task-switch context
- **AND** any persistent context lane stays orienting and compact instead of
  becoming a second scrollable library wall

#### Scenario: Operator enters a secondary library from the active workflow

- **GIVEN** the operator needs a preset, saved profile, managed provider, or
  provider family that is not part of the current first read
- **WHEN** the operator invokes the relevant explicit library action
- **THEN** the shell opens that library as a secondary surface with a clear
  return path
- **AND** the first-screen workflow remains the default landing surface after
  the operator exits that library

### Requirement: Desktop GUI offers explicit preset bootstrap entry surfaces

The system SHALL let the desktop GUI offer preset bootstrap through explicit
task-start surfaces instead of relying on always-visible preset cards beside
the active editor.

#### Scenario: Desktop bootstrap uses an available preset from an explicit entry surface

- **GIVEN** the connected host advertises the provider descriptor targeted by
  one of the preset entries
- **WHEN** the operator opens the preset bootstrap surface and chooses the
  `VK`, `WB Stream`, or `RTK Smarthome` preset
- **THEN** the GUI seeds a new draft with that preset's provider family and
  curated defaults
- **AND** the operator can continue through the active workflow without keeping
  the entire preset catalog permanently visible

#### Scenario: Desktop keeps unavailable presets explicit inside the bootstrap surface

- **GIVEN** a preset whose target provider is not advertised by the connected
- **host**
- **WHEN** the operator opens the explicit preset bootstrap surface
- **THEN** the unavailable preset remains visible with explicit unavailable copy
- **AND** the GUI does not silently create a fake draft for that provider
