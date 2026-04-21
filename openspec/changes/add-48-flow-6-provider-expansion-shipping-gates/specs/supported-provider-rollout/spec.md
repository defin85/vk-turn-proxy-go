## ADDED Requirements
### Requirement: Provider promotion into the shipped catalog is explicit and evidence-gated

The system SHALL promote a future provider family into the ordinary shipped
supported-provider catalog only through an explicit product-owned rollout gate.

#### Scenario: Researched provider remains out of the shipped catalog

- **GIVEN** the repository contains research notes, archived proposals, or
  disabled bootstrap assets for a future provider family
- **WHEN** no committed rollout gate has promoted that family into shipped
  support
- **THEN** the ordinary operator-facing supported-provider catalog does not
  treat that family as shipped support
- **AND** the repository does not imply that research or planned work is
  equivalent to operator-facing availability

#### Scenario: Provider promotion requires the committed support surface

- **GIVEN** a future provider family is proposed for shipped support
- **WHEN** the repository evaluates whether to promote it into the ordinary
  supported-provider catalog
- **THEN** promotion requires a provider-specific contract plus the matching
  artifact-family action surface
- **AND** it requires verification evidence for the committed host and shell
  surfaces
- **AND** the family does not become shipped support before those conditions
  are satisfied

### Requirement: Non-authoritative assets do not imply shipped provider support

The system SHALL treat presets, templates, and research artifacts as
non-authoritative for shipped provider support unless a committed rollout gate
promotes that provider family explicitly.

#### Scenario: Preset exists for an unshipped provider family

- **GIVEN** a preset, template, or other bootstrap asset references a provider
  family that is not yet promoted into shipped support
- **WHEN** the repository or shell evaluates ordinary operator-facing support
- **THEN** that asset does not count as proof that the provider family is
  shipped
- **AND** the product does not treat bootstrap assets as a substitute for the
  committed rollout gate

#### Scenario: Archived provider research exists without rollout approval

- **GIVEN** archived research or design work exists for a future provider
  family
- **WHEN** no later committed change promotes that family into shipped support
- **THEN** the repository keeps the family in planned or research state
- **AND** it does not surface that family as ordinary shipped support by
  implication

### Requirement: Partial provider rollout stays fail-closed

The system SHALL keep provider rollout fail-closed when host, desktop, mobile,
or verification readiness is incomplete.

#### Scenario: Host work lands before the committed shell surfaces

- **GIVEN** host-side descriptor or resolver work exists for a future provider
  family
- **WHEN** the committed desktop or mobile operator surfaces are still missing
- **THEN** the provider family stays out of the ordinary shipped catalog
- **AND** the repository does not claim that one partial surface is equivalent
  to shipped provider support

#### Scenario: One platform is ready while another remains unverified

- **GIVEN** a future provider family appears ready on one platform but another
  committed platform remains unverified or unsupported
- **WHEN** the repository evaluates ordinary shipped support
- **THEN** the family remains fail-closed until the committed rollout gate is
  satisfied
- **AND** the repository may track the pending state explicitly without
  promoting the family into the ordinary shipped catalog
