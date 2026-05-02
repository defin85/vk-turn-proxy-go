# wireguard-turn-carrier Specification

## Purpose
Define the strict TURN-backed `turn_datagram + wireguard_native` carrier contract, including host-owned execution leases, secret boundaries, and evidence requirements for support claims.
## Requirements
### Requirement: Strict WireGuard startup uses a host-owned execution lease

The system SHALL require a host-owned, secret-bearing execution lease before a
resolved `generic_turn` artifact can become a startable strict
`turn_datagram + wireguard_native` path.

#### Scenario: Host materializes a strict WireGuard execution lease

- **GIVEN** a resolved `generic_turn` artifact that advertises
  `turn_credentials` and a strict `wireguard_native` execution plan with
  `carrier_family=turn_datagram`
- **WHEN** the host prepares same-device startup for that strict plan
- **THEN** the host materializes or derives the secret-bearing WireGuard and
  carrier state required for the documented path
- **AND** that lease is owned by the host runtime instead of ordinary shell
  state
- **AND** the shell does not need to synthesize WireGuard keys, peer settings,
  or carrier bindings from ordinary artifact fields

### Requirement: Ordinary reads do not expose the execution lease

The system SHALL keep strict WireGuard execution leases out of ordinary
artifact, resolution, session, event, and persisted shell state reads.

#### Scenario: Host advertises strict WireGuard startup without leaking lease material

- **GIVEN** a host build that can start a strict `turn_datagram`
  `wireguard_native` path
- **WHEN** the host returns ordinary artifact or session state to a shell
- **THEN** it exposes only the documented non-secret planning metadata and typed
  runtime state
- **AND** it does not serialize raw WireGuard private keys, peer keys, or other
  startable carrier-secret material through those ordinary reads

### Requirement: Strict WireGuard carrier stays distinct from the overlay runtime

The system SHALL keep the strict TURN-backed WireGuard carrier separate from
the current `turn_dtls_overlay + custom_packet_overlay` runtime.

#### Scenario: Strict WireGuard path does not fall back to overlay semantics

- **GIVEN** a requested same-device execution plan with
  `carrier_family=turn_datagram` and `engine_family=wireguard_native`
- **WHEN** the host validates or starts that path
- **THEN** it uses the documented strict TURN-backed datagram carrier semantics
- **AND** it does not silently reinterpret the request as the current
  `turn_dtls_overlay + custom_packet_overlay` runtime
- **AND** support for one path does not imply support for the other

### Requirement: The strict WireGuard remote role under `turn_server` is explicit

The system SHALL define the strict WireGuard-over-TURN datagram role under the
existing `turn_server` endpoint family explicitly instead of implying that the
current DTLS overlay server already satisfies it.

#### Scenario: Remote endpoint role is explicit for strict WireGuard startup

- **GIVEN** a strict `turn_datagram` `wireguard_native` execution plan
- **WHEN** the repository documents or implements the remote endpoint needed for
  that plan
- **THEN** the remote role under `turn_server` is documented explicitly for
  WireGuard-over-TURN datagram termination
- **AND** the host does not assume that the existing DTLS overlay server role is
  already sufficient by implication

### Requirement: Strict WireGuard support claims require carrier evidence

The system SHALL require repo-owned carrier evidence before any packaged host
claims support for the strict `turn_datagram + wireguard_native` path.

#### Scenario: Packaged host claims strict WireGuard support

- **GIVEN** a packaged host that reports a strict `wireguard_native` execution
  plan as startable
- **WHEN** that support claim is documented or shipped
- **THEN** repo-owned evidence covers host-owned materialization, secret
  redaction, fail-closed startup, and real WG traffic over the strict
  `turn_datagram` path
- **AND** the repository does not treat external WireGuard compatibility
  workflows or the current overlay runtime as equivalent proof

### Requirement: WireGuard carrier consumes profile material through the profile store

The strict `turn_datagram + wireguard_native` carrier SHALL consume local
WireGuard material through a host-owned VPN transport profile or an explicitly
documented host-owned material source with equivalent lifecycle and redaction
semantics, not through hidden packaged seed files, shell-visible file paths,
environment fallbacks, or ordinary provider artifact payloads.

#### Scenario: WireGuard execution lease derives from a profile reference

- **GIVEN** a resolved `generic_turn` artifact and a selected strict
  `turn_datagram + wireguard_native` execution plan
- **AND** a compatible `wireguard_native_v1` transport profile is selected
- **WHEN** the host prepares the strict WireGuard execution lease
- **THEN** the host derives the secret-bearing startup material internally from
  the selected profile and artifact
- **AND** ordinary shell-visible responses expose only redacted lease/profile
  status

#### Scenario: Packaged seed file is not a WireGuard material source

- **GIVEN** a packaged host starts a strict `wireguard_native` path
- **WHEN** it looks for required local WireGuard material
- **THEN** hidden packaged files such as `assets/wireguard/phone1.conf`,
  workstation-local defaults, and environment fallback paths are not valid
  product material sources
- **AND** missing profile-store material fails closed before readiness is
  reported

### Requirement: WireGuard carrier consumes structured profile material

The WireGuard TURN carrier SHALL materialize accepted structured
`wireguard_native_v1` profile fields through the same execution lease path used
by imported WireGuard profiles.

#### Scenario: Structured profile starts WireGuard carrier

- **GIVEN** a `wireguard_native_v1` profile was created or updated through the
  structured editor
- **AND** the profile is compatible with a strict TURN datagram WireGuard
  execution plan
- **WHEN** platform tunnel startup materializes a WireGuard execution lease
- **THEN** the lease uses the stored profile id as its transport-profile source
- **AND** accepted interface addresses, peer public key, allowed IPs, DNS
  servers, MTU, endpoint source, and supported optional fields are reflected in
  the lease
- **AND** startup responses remain redacted

#### Scenario: Accepted field cannot be materialized

- **GIVEN** the host advertises a structured WireGuard field as supported
- **AND** the operator saves that field in a valid profile
- **WHEN** startup materialization cannot apply that field to the selected
  carrier or host adapter
- **THEN** startup fails closed with a transport-profile validation failure
- **AND** the host does not silently drop the field while reporting readiness
