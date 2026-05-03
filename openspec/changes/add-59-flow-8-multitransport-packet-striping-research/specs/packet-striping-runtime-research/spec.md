## ADDED Requirements
### Requirement: Packet striping remains outside shipped support until a later implementation change

The system SHALL keep packet-level striping outside ordinary shipped runtime
support until a later reviewed implementation change satisfies the documented
research and verification bar.

#### Scenario: Throughput anecdote does not promote striping support

- **GIVEN** the repository has one prototype, benchmark, or anecdotal report
  suggesting that packet striping could improve throughput
- **WHEN** the repository evaluates runtime support status
- **THEN** packet striping remains outside shipped support
- **AND** the repository does not treat that anecdote as sufficient proof of
  product readiness

### Requirement: Packet striping readiness requires explicit ordering and recovery design

The system SHALL not claim packet-striping readiness without an explicit design
for ordering, reordering, duplication, and congestion behavior across child
paths.

#### Scenario: Striping design omits global ordering or recovery semantics

- **GIVEN** a proposed packet-striping design for one logical runtime flow
- **WHEN** that design omits one documented ordering, reorder-buffer,
  duplicate-suppression, or congestion-control strategy
- **THEN** the repository does not treat packet striping as ready for shipped
  support
- **AND** the gap remains explicit in the research boundary

### Requirement: Packet striping support claims require repo-owned live evidence

The system SHALL require repo-owned live evidence against documented striping
budgets before any future shipped support claim is made.

#### Scenario: Future striping implementation claims support

- **GIVEN** a future change proposes shipped packet-striping support
- **WHEN** the repository evaluates that claim
- **THEN** the claim requires repo-owned live evidence for throughput,
  reordering, duplicate handling, and failure recovery against documented
  budgets
- **AND** it does not inherit support status from `active_standby` or
  `flow_sharded` runtime alone

### Requirement: Packet striping research distinguishes same-ceiling and independent-domain paths

The system SHALL treat child-path independence as part of the packet-striping
research bar before any future bandwidth-recovery claim can ship.

#### Scenario: Striped child paths share one provider-side ceiling

- **GIVEN** a packet-striping prototype or design that uses multiple child
  paths inside one provider, call, TURN policy, or traffic class
- **WHEN** live evidence shows those child paths share one throughput ceiling
- **THEN** the repository does not treat packet striping as a bandwidth
  recovery feature for that contour
- **AND** the result remains research evidence rather than shipped support
- **AND** a future shipped claim still requires independent-domain A/B evidence
