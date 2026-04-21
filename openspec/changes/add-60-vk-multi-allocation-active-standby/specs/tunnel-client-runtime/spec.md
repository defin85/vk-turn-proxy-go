## ADDED Requirements
### Requirement: Explicit VK active-standby policy keeps one payload path active

The system SHALL let the tunnel client run one explicit VK-only
`active_standby` policy that keeps one same-tuple payload path active while
other established VK allocations remain on standby.

#### Scenario: Successful VK active-standby startup

- **GIVEN** a supported VK runtime startup request that selects the explicit
  `active_standby` policy and requests one active allocation plus one or more
  standby allocations for one supported transport tuple
- **WHEN** the operator starts `cmd/tunnel-client`
- **THEN** the runtime resolves VK credentials once for that session attempt
- **AND** establishes the requested active and standby allocations before
  reporting readiness
- **AND** reports one logical session identity across those allocations

#### Scenario: UDP forwarding uses the active allocation until promotion

- **GIVEN** a running VK `active_standby` session with one active allocation
  and at least one ready standby allocation
- **WHEN** local applications send UDP datagrams to the client listen address
- **THEN** the runtime forwards those datagrams through the current active
  allocation
- **AND** standby allocations do not carry ordinary payload before promotion

#### Scenario: Standby allocation is promoted after active-path failure

- **GIVEN** a running VK `active_standby` session whose current active
  allocation fails after readiness
- **WHEN** one standby allocation remains established and eligible for
  promotion under the committed runtime policy
- **THEN** the runtime may promote that standby allocation into the active role
- **AND** it does not imply that both allocations were carrying the same
  payload concurrently before promotion
