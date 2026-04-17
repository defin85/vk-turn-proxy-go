## ADDED Requirements
### Requirement: Android embedded host can preserve the active local network for development-safe VPN startup

The system SHALL let the packaged Android embedded host prepare an explicit
development underlay-route profile for `android_vpn_service` startup while
keeping the mode itself a normal Android system tunnel.

#### Scenario: Host starts Android VPN with development local-network preservation

- **GIVEN** the packaged Android host supports the typed underlay-route policy
  `preserve_active_local_network`
- **AND** the device has an active local underlay network
- **WHEN** the mobile GUI requests Android VPN startup with that policy
- **THEN** the host computes and applies the required local-network route
  exclusions for that active network
- **AND** the packaged runtime still starts through the documented Android VPN
  host boundary

#### Scenario: Host cannot prepare the requested development profile

- **GIVEN** the mobile GUI requests `preserve_active_local_network`
- **WHEN** the packaged Android host cannot determine or safely apply the
  active local-network exclusion set
- **THEN** startup fails closed before readiness is reported
- **AND** the app does not silently fall back to the standard routing profile

#### Scenario: Host surfaces effective development underlay-route state

- **GIVEN** Android VPN startup succeeded with a typed underlay-route policy
- **WHEN** the shell inspects host-reported status or diagnostics
- **THEN** the host reports the selected underlay-route policy and the fact
  that local-network preservation was applied
- **AND** diagnostics can distinguish that state from the standard routing
  profile
