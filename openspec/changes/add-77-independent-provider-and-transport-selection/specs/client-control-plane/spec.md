## ADDED Requirements
### Requirement: Client control plane carries provider and transport selections separately

The client control plane SHALL represent startup intent with separate provider
source or resolution references and VPN transport profile references.

#### Scenario: Shell submits explicit source and transport references

- **GIVEN** a shell has selected a provider source or resolved provider
  artifact
- **AND** the shell has selected a VPN transport profile for the chosen runtime
  plan
- **WHEN** the shell requests same-device platform-tunnel startup
- **THEN** the request identifies the provider/source or resolution side
  separately from the transport profile reference
- **AND** the host validates the combined runtime execution plan before
  reporting readiness
- **AND** the request does not serialize provider secrets into the transport
  profile payload or transport-profile secrets into the provider payload

#### Scenario: Host rejects stale selection from one axis

- **GIVEN** the shell sends a stale provider resolution, unavailable provider
  source, missing transport profile, or incompatible transport profile
- **WHEN** startup validation runs
- **THEN** the host fails closed with a typed reason naming the failing axis
- **AND** it does not silently replace the stale provider side with another
  provider source
- **AND** it does not silently replace the transport profile side with the last
  edited, imported, or displayed transport profile
