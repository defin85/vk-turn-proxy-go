## ADDED Requirements

### Requirement: Desktop application routing is identity-based and capability-gated

The system SHALL model desktop application routing as a host-enforced selector
policy over host-reported desktop application identities instead of destination
IP rules or Android package names.

#### Scenario: Host cannot enforce desktop application identity

- **GIVEN** a desktop host that can start a platform tunnel mode such as
  `windows_wintun`
- **AND** that host lacks a verified app classifier or enforcement layer for
  the requested mode
- **WHEN** the shell queries desktop app-routing capability
- **THEN** the host reports desktop app routing as unsupported for that mode
- **AND** the shell does not infer app-routing support from platform-tunnel
  readiness alone

#### Scenario: Host advertises enforceable desktop app routing

- **GIVEN** a desktop host with a verified app classifier or enforcement layer
  for one platform tunnel mode
- **WHEN** the shell queries desktop app-routing capability
- **THEN** the host reports the supported mode, policy kinds, identity kinds,
  and any required prerequisites explicitly
- **AND** the shell may offer app selection only for that advertised scope

### Requirement: Desktop app identities are not Android package selectors

The system SHALL keep desktop application identities separate from Android
package selectors so each platform can validate app-routing scope inside its
native host boundary.

#### Scenario: Desktop selector uses desktop identity metadata

- **GIVEN** a desktop host reports an application inventory
- **WHEN** the shell renders selectable app-routing targets
- **THEN** each target includes a host-owned stable identity key
- **AND** it may include desktop metadata such as executable path, identity
  kind, display name, signing metadata, or platform-specific app id
- **AND** it does not require an Android package name

#### Scenario: Android package policy remains unchanged

- **GIVEN** a packaged Android host starts `android_vpn_service`
- **WHEN** the shell submits `application_routing_policy`,
  `allowed_packages`, or `disallowed_packages`
- **THEN** that request remains governed by the Android platform-tunnel
  contract
- **AND** desktop hosts do not reinterpret those package fields as executable
  paths or desktop app identifiers

### Requirement: Desktop app-routing scope changes are explicit startup changes

The system SHALL treat changes to desktop app-routing scope as explicit startup
or reconnect changes unless a later contract defines live scope mutation.

#### Scenario: Operator changes selected desktop apps after readiness

- **GIVEN** a desktop platform tunnel is ready with one app-routing selector
  policy
- **WHEN** the operator changes the selected app set
- **THEN** the shell presents that change as requiring a new startup attempt or
  reconnect
- **AND** it does not imply that the running tunnel scope changed until the host
  reports a new ready result for the updated policy
