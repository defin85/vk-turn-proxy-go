# build-versioning Specification

## Purpose
Define the canonical product-version and build-identity contract that packaged binaries, hosts, and GUI shells surface to operators.
## Requirements
### Requirement: Supported artifacts use a canonical product version and build identity

The system SHALL stamp supported Go and Flutter artifacts with a canonical product version and build identity derived from one repo-managed structured version manifest that is separate from local control-plane contract negotiation.

#### Scenario: Structured manifest defines the canonical version source

- **GIVEN** the repository build workflows for supported artifacts
- **WHEN** a supported artifact is built through a repo-owned workflow
- **THEN** the workflow reads product version and build number from one structured manifest
- **AND** it does not rely on unrelated ad-hoc version files as an alternative source of truth

#### Scenario: Repo-owned Go build stamps product version and revision

- **GIVEN** a supported Go artifact built through the repo-owned build workflow
- **WHEN** the build completes successfully
- **THEN** the artifact carries the canonical product version
- **AND** it also carries build identity metadata such as revision and build state instead of exposing only the control-plane contract version

#### Scenario: Repo-owned Flutter GUI build uses the same product version source

- **GIVEN** the desktop GUI is built through the repo-owned Flutter packaging workflow
- **WHEN** the GUI artifact is staged
- **THEN** the GUI package version and runtime-visible app identity come from the same canonical product version source used by the supported Go artifacts
- **AND** the build fails closed if the GUI-facing version inputs are missing or inconsistent

### Requirement: Control-plane host info exposes build identity separately from contract compatibility

The system SHALL expose host build identity separately from control-plane contract version so GUI shells can distinguish "compatible API" from "which build is running".

#### Scenario: Compatible GUI reads host build identity

- **GIVEN** a desktop GUI connects to a compatible local host
- **WHEN** it queries host metadata and negotiates compatibility
- **THEN** the host reports contract compatibility version separately from host build identity
- **AND** the GUI can display both without relabeling the contract version as the product version

#### Scenario: Host is present but incompatible

- **GIVEN** a local host is reachable but fails control-plane compatibility negotiation
- **WHEN** the desktop GUI inspects host metadata
- **THEN** the GUI can still surface the detected host build identity when available
- **AND** the incompatibility remains explicit instead of silently falling back to unsupported behavior

### Requirement: Desktop GUI surfaces local app version and host version distinctly

The system SHALL surface the desktop GUI build identity and the connected host build identity as separate values in the GUI.

#### Scenario: Ready host shows app and host versions

- **GIVEN** the desktop GUI is running with a compatible local host
- **WHEN** the shell renders host status
- **THEN** it shows the GUI app version/build identity
- **AND** it shows the connected host version/build identity
- **AND** it labels any contract compatibility version separately

#### Scenario: Incompatible host shows version context

- **GIVEN** the desktop GUI finds a local host that does not satisfy the required control-plane version
- **WHEN** the blocked-state banner is rendered
- **THEN** the GUI reports the incompatibility explicitly
- **AND** it still shows enough version context for the operator to tell which GUI build and which host build are involved

### Requirement: Diagnostics bundles persist build identity context

The system SHALL include build identity context in diagnostics bundles so exported support artifacts preserve the same version information surfaced by the GUI and control plane.

#### Scenario: Session diagnostics bundle includes GUI and host build identity

- **GIVEN** a desktop GUI exports diagnostics for a session
- **WHEN** the diagnostics bundle is written
- **THEN** the bundle includes the GUI build identity that initiated the export
- **AND** it includes the host build identity associated with the session
- **AND** it includes the relevant control-plane contract version separately from the human-facing build identity
