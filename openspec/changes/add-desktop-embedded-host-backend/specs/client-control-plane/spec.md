## ADDED Requirements
### Requirement: Client control plane is transport-neutral across loopback and embedded desktop hosts

The client control-plane contract SHALL define stable host semantics
independent of whether a desktop shell reaches the host through loopback HTTP
or a process-local embedded adapter. Transport selection SHALL NOT create a
second shell-visible API, schema, capability vocabulary, or event model.

#### Scenario: Embedded and sidecar hosts report the same contract

- **GIVEN** a desktop shell can negotiate with either a loopback `clientd`
  sidecar or an embedded desktop host backend
- **WHEN** the shell requests host info and negotiation
- **THEN** both backends report the same control-plane versioning model,
  required capabilities, build identity shape, and typed capability metadata
- **AND** the shell can reject incompatible hosts through the same negotiation
  path

#### Scenario: Embedded adapter preserves typed operations

- **GIVEN** the shell is connected to an embedded desktop host backend
- **WHEN** it manages providers, profiles, transport profiles, resolutions,
  sessions, challenges, diagnostics, events, or platform tunnels
- **THEN** those operations return the same typed records and failures as the
  loopback control-plane contract
- **AND** callers do not need backend-specific parsing or fallback behavior
