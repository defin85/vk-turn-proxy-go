# runtime-execution-planning Specification

## Purpose
Define the typed runtime execution-plan matrix for same-device startup across access methods, carrier families, engine families, host adapters, and explicit remote endpoint ownership.
## Requirements
### Requirement: Host-owned same-device execution uses typed runtime execution plans

The system SHALL describe each host-owned same-device execution path through a typed runtime execution plan that keeps `access_method`, `carrier_family`, `engine_family`, and optional `host_adapter` explicit instead of collapsing those concerns into one provider-specific or platform-specific mode string.

#### Scenario: Host reports a TURN-backed packaged system-tunnel plan

- **GIVEN** a resolved artifact whose supported same-device action consumes `turn_credentials`
- **AND** the current host build supports one packaged system-tunnel adapter such as `android_vpn_service` or `windows_wintun`
- **WHEN** the host reports the available same-device execution plans for that artifact
- **THEN** each supported packaged system-tunnel plan names its `access_method`, `carrier_family`, `engine_family`, and `host_adapter` explicitly
- **AND** the shell does not need to infer those choices from the provider identifier or one generic mode string

#### Scenario: Host reports an in-call data-channel plan separately from TURN

- **GIVEN** a resolved artifact that may later support host-owned same-device execution through an in-call attachment path
- **WHEN** the host reports available execution plans for that artifact
- **THEN** any such plan names `webrtc_call_attach` or another documented non-TURN access method explicitly
- **AND** it names `webrtc_datachannel` or another documented non-TURN carrier family explicitly
- **AND** the host does not pretend that this plan is equivalent to TURN-backed execution

### Requirement: Runtime execution support is an explicit compatibility matrix

The system SHALL represent supported runtime execution paths as an explicit compatibility matrix between access methods, carrier families, engine families, and host adapters.
Unsupported combinations SHALL fail closed.

#### Scenario: Unsupported carrier and engine combination is rejected

- **GIVEN** a resolved artifact whose access method is known to the host
- **AND** the current build does not document a supported compatibility edge for the requested carrier or engine family
- **WHEN** the caller requests same-device execution through that unsupported plan
- **THEN** the host fails explicitly before claiming readiness
- **AND** it identifies the requested plan as unsupported or unavailable
- **AND** it does not synthesize a guessed fallback plan

#### Scenario: Support on one host adapter does not imply another

- **GIVEN** a host build that documents one supported execution plan for one host adapter family
- **WHEN** another host adapter family lacks its own documented compatibility edge for the same access method, carrier, or engine family
- **THEN** the host reports that second plan as unsupported or unavailable
- **AND** the shell does not treat the first supported plan as proof that the second one exists

### Requirement: The first packaged system-tunnel ready paths stay intentionally narrow

The system SHALL keep the first packaged Android and desktop system-tunnel support claims scoped to documented TURN-backed `wireguard_native` execution plans until later changes add and verify additional engine families explicitly.

#### Scenario: First packaged system-tunnel path remains `wireguard_native`

- **GIVEN** a packaged host that reaches `ready=true` for one documented platform tunnel mode
- **WHEN** the host reports the supported same-device execution plans for that mode
- **THEN** the supported packaged system-tunnel plan is explicitly documented as TURN-backed and `wireguard_native`
- **AND** the host does not imply that `webrtc_datachannel`, `proxy_core_adapter`, `trusttunnel_native`, or another engine family is also supported for that same mode

### Requirement: Experimental and foreign-core execution plans are capability-gated

The system SHALL advertise experimental carriers and foreign-core engine families only through explicit capability and support-state metadata.
They SHALL NOT be treated as generic defaults for packaged system-tunnel startup.

#### Scenario: Experimental `webrtc_datachannel` plan stays opt-in

- **GIVEN** a host build that exposes an experimental execution plan using `webrtc_datachannel`
- **WHEN** a shell reads the execution plans for the resolved artifact
- **THEN** the plan is marked through explicit capability or support-state metadata as experimental or otherwise non-default
- **AND** the shell does not silently auto-select it as the packaged system-tunnel path

#### Scenario: Foreign-core engine family is unavailable on the current build

- **GIVEN** a host build that does not package or verify one documented foreign-core engine family
- **WHEN** a caller requests same-device execution through that engine family
- **THEN** the host reports the requested plan as unavailable
- **AND** it does not substitute another engine family implicitly

### Requirement: Carrier families keep distinct remote endpoint ownership

The system SHALL keep remote endpoint ownership explicit per carrier family instead of treating the current TURN-backed server role as a universal backend for all future execution plans.

#### Scenario: TURN-backed and non-TURN plans use different remote endpoint families

- **GIVEN** one supported execution plan whose carrier family is TURN-backed
- **AND** another documented plan whose carrier family is `webrtc_datachannel` or another non-TURN family
- **WHEN** the repository documents or reports the remote endpoint requirement for those plans
- **THEN** the TURN-backed plan continues to name the documented TURN server family
- **AND** the non-TURN plan requires its own documented remote endpoint family
- **AND** the host does not imply that the current TURN server already satisfies that non-TURN role
