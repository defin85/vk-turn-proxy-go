## ADDED Requirements
### Requirement: Packaged Linux transport profile store remains user-space across privilege split

Packaged Linux desktop hosts SHALL keep VPN transport-profile persistence
owned by the operator user's unprivileged local host. The privileged Linux
`linux_tun` helper SHALL receive only materialized, attempt-scoped execution
leases and SHALL NOT read, write, select, or migrate the long-lived transport
profile store during native tunnel startup.

#### Scenario: User-space host owns packaged Linux profiles

- **GIVEN** a packaged Linux desktop host starts as the operator user
- **WHEN** the shell lists, edits, imports, replaces, forgets, validates, or
  selects VPN transport profiles
- **THEN** those operations use the operator user's host-owned profile store
- **AND** they remain available before any Linux privilege prompt is requested

#### Scenario: Legacy root-owned package store is not a second live source

- **GIVEN** a previous packaged Linux build created a root-owned transport
  profile store such as `/var/lib/relaydock/vpn-transport-profiles/store.json`
- **WHEN** the user-space host starts after this change
- **THEN** it either migrates/imports the legacy state exactly once through a
  reviewed migration path or reports setup-needed diagnostics for manual
  repair
- **AND** after migration or repair, startup uses the user-space profile id
  rather than reading the root-owned path as a parallel live store

#### Scenario: Helper receives only materialized lease

- **GIVEN** a selected VPN transport profile is compatible with a packaged
  Linux `linux_tun` execution plan
- **WHEN** the unprivileged host invokes the privileged helper
- **THEN** the helper receives only the materialized ephemeral execution lease
  and attempt-scoped route or DNS directives
- **AND** the payload excludes profile-store paths, raw profile records,
  profile editing fields, default-selection metadata, and import material
