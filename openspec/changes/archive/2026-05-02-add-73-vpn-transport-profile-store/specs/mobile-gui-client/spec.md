## ADDED Requirements

### Requirement: Mobile GUI presents VPN transport profiles generically

The mobile GUI SHALL present required local VPN transport material as VPN
transport profiles, with WireGuard shown as the first supported profile type,
instead of presenting the product workflow as a hidden or path-based
WireGuard-only configuration prerequisite.

#### Scenario: Missing profile blocks VPN startup with setup action

- **GIVEN** the selected mobile mode is `android_vpn_service`
- **AND** the selected execution plan requires a `wireguard_native_v1`
  transport profile
- **AND** no compatible profile is configured
- **WHEN** the operator inspects the VPN home surface
- **THEN** the VPN start action is setup-gated or disabled
- **AND** the setup action names the missing VPN transport profile prerequisite
  and offers the supported WireGuard import adapter
- **AND** the UI does not instruct the operator to stage a hidden `phone1.conf`
  file

#### Scenario: Configured profile is visible without exposing secrets

- **GIVEN** a compatible VPN transport profile is configured
- **WHEN** the operator inspects the VPN home or settings surface
- **THEN** the UI shows the profile kind, safe display metadata, and status
- **AND** it offers replace and forget actions
- **AND** it does not show raw private keys, peer secrets, or app-private
  storage paths

#### Scenario: Future profile kind does not reuse WireGuard copy

- **GIVEN** a future host advertises a non-WireGuard transport profile kind
- **WHEN** the mobile GUI renders profile setup for that plan
- **THEN** the setup surface is driven by the advertised profile kind and
  adapters
- **AND** it does not force WireGuard `.conf` copy or validation for that
  future engine
