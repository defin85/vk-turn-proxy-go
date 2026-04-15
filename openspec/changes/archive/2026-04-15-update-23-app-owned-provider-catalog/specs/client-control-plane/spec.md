## MODIFIED Requirements
### Requirement: Client control plane exposes provider catalog discovery

The system SHALL expose a typed provider catalog through the local control
plane so shells can discover runtime provider constraints without hard-coding
workflow logic to provider identifiers.

#### Scenario: Shell requests provider catalog from a compatible host

- **GIVEN** a compatible host with one or more supported providers
- **WHEN** a shell requests the provider catalog
- **THEN** the host returns typed descriptors for each advertised provider
- **AND** each descriptor includes the runtime metadata needed for validation,
  availability, browser policy, and provider-specific UX
- **AND** the shell may combine those descriptors with an app-owned supported
  provider catalog instead of treating the host descriptor list as its only
  operator-facing provider taxonomy

#### Scenario: App-owned shell workflow does not require provider-config capability

- **GIVEN** a host that advertises typed provider descriptors but does not
  expose `provider_configs` as a required capability
- **WHEN** a desktop or mobile shell negotiates for the app-owned provider
  workflow from this change
- **THEN** the shell can still treat that host as compatible for ordinary
  managed-provider and profile workflows
- **AND** host-managed provider-config CRUD remains an optional compatibility
  surface rather than a required dependency

### Requirement: Client control plane accepts descriptor-declared provider settings

The system SHALL let providers declare reusable user-configurable settings as
part of the provider entry contract without requiring shell-specific hard-coded
fields.

#### Scenario: Shell starts resolution from a managed-provider snapshot

- **GIVEN** a shell-managed provider record materialized into ordinary
  `provider`, `link`, and `provider_settings` values
- **WHEN** a shell starts resolution or session startup through the control
  plane
- **THEN** the host validates the resulting provider settings against the
  descriptor-declared schema for that provider
- **AND** the control-plane contract does not require a shell-managed provider
  identifier
- **AND** the host handles the materialized request the same way as an
  equivalent custom operator-entered request

## REMOVED Requirements
### Requirement: Client control plane manages reusable provider configs

**Reason**: Reusable provider inventory moves to shell-owned managed-provider
records instead of host-owned provider-config CRUD as the primary workflow.

**Migration**: Desktop and mobile shells materialize managed providers into
ordinary `provider` and `provider_settings` snapshots before calling the
control plane. Existing host-side provider-config endpoints may remain as
optional compatibility surfaces during rollout.

### Requirement: Provider-config validation stays descriptor-driven

**Reason**: Host-side validation remains descriptor-driven for materialized
provider settings, but the host no longer owns the primary reusable-provider
record type.

**Migration**: Shell-managed provider records use host descriptors as a runtime
validation overlay when compiling managed-provider snapshots into control-plane
requests.

### Requirement: Profile apply from a provider config is snapshot-based

**Reason**: Profiles now apply shell-managed provider records rather than
host-managed provider configs.

**Migration**: The snapshot rule stays in force, but the reusable source
record is a managed provider in shell-owned state.
