## ADDED Requirements
### Requirement: Client control plane negotiates provider/transport compatibility support

The client control plane SHALL advertise provider/transport compatibility
support through explicit host capability metadata.

#### Scenario: Updated shell connects to older host

- **GIVEN** a shell build expects provider/transport compatibility candidates
- **WHEN** it negotiates with a host that does not advertise that capability
- **THEN** the shell treats the combined selector as unavailable or
  incompatible
- **AND** it does not try to compute startability from unrelated provider and
  transport profile responses alone

### Requirement: Client control plane returns a combined compatibility read model

The client control plane SHALL provide a typed response for provider/source and
VPN transport profile compatibility evaluation.

#### Scenario: Compatibility response includes source and transport facts

- **GIVEN** a shell requests compatibility for a selected provider/source or
  resolved artifact and a selected VPN transport profile
- **WHEN** the host evaluates the request
- **THEN** the response includes the provider/source reference, resolved
  artifact or resolution reference when applicable, runtime execution plan
  identity, required transport profile kind, selected profile id when
  applicable, status, failing axis, and reason metadata
- **AND** it keeps provider secrets and transport-profile secrets redacted
- **AND** status, failing-axis, and reason-code values are stable
  machine-readable values rather than display text
- **AND** a shell that receives an unknown status or failing axis treats the
  candidate as non-startable until the host capability contract is upgraded

### Requirement: Client control plane validates explicit candidate startup

The client control plane SHALL require startup requests for combined source and
transport flows to identify the selected candidate or its equivalent explicit
source, plan, and transport-profile references.

#### Scenario: Startup request omits selected axis

- **GIVEN** the selected runtime path requires both a provider/source side and a
  VPN transport profile side
- **WHEN** the shell sends a startup request that omits one required reference
- **THEN** the host fails before provider, carrier, engine, or native adapter
  startup
- **AND** the response identifies the missing axis
- **AND** the host does not fill the missing axis from last-used or most-recent
  compatible state
