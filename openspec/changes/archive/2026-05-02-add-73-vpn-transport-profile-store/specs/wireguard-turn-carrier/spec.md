## ADDED Requirements

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
