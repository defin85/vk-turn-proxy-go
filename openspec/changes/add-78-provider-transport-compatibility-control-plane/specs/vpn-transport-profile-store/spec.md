## ADDED Requirements
### Requirement: Transport profile store exposes compatibility inputs for evaluation

The VPN transport profile store SHALL expose redacted profile status and scoped
selection state needed by the provider/transport compatibility evaluator.

#### Scenario: Selected profile participates in compatibility evaluation

- **GIVEN** a VPN transport profile is selected or scoped as default for one
  execution plan
- **WHEN** the compatibility evaluator reads profile-store state
- **THEN** it can use profile id, kind, validation status, compatibility
  status, selected/default binding, and supported actions
- **AND** it does not read raw secret material or host-private filesystem paths
  into the compatibility response

#### Scenario: Compatible but unselected profile does not make startup ready

- **GIVEN** one or more VPN transport profiles are compatible with a requested
  execution plan
- **AND** none is explicitly selected or scoped as default for that plan
- **WHEN** compatibility candidates are evaluated
- **THEN** the combination is setup-needed or unselected rather than startable
- **AND** the evaluator does not choose the last edited, imported, displayed,
  or first compatible profile as an implicit startup selection
