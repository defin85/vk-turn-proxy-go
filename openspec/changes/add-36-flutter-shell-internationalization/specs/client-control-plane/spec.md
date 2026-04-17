## ADDED Requirements

### Requirement: Client control plane exposes locale-aware display metadata

The system SHALL let shells request locale-aware provider and validation
display metadata without changing stable machine-readable ids, field keys, or
violation codes.

#### Scenario: Shell requests provider catalog display metadata with locale preference

- **GIVEN** a compatible host and a shell with an active locale preference
- **WHEN** the shell requests provider catalog or provider-setting display
  metadata through the local control plane
- **THEN** the host may return localized provider names, provider
  descriptions, provider-setting labels, and provider-setting descriptions for
  the requested locale
- **AND** the stable provider identifiers and provider-setting keys remain
  unchanged for program logic

#### Scenario: Shell receives localized validation or availability messages

- **GIVEN** a host that validates provider settings or reports provider
  availability
- **WHEN** the host emits display-oriented availability or validation messages
- **THEN** the host may include localized display text that matches the
  shell-requested locale
- **AND** the stable machine-readable state and violation fields remain
  locale-neutral
- **AND** the shell does not need to recover action meaning from localized text

#### Scenario: Older or untranslated hosts stay compatible

- **GIVEN** a shell that supports localized control-plane display metadata
- **WHEN** it connects to a host that returns only base display strings
- **THEN** the host remains compatible for the existing provider catalog and
  validation contracts
- **AND** the shell falls back to the base strings instead of rejecting the
  host or inventing translations from machine-readable identifiers
