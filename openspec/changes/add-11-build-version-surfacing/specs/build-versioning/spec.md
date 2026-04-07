## ADDED Requirements
### Requirement: Supported artifacts use a canonical product version and build identity

The system SHALL stamp supported Go and Flutter artifacts with a canonical product version and build identity that is separate from local control-plane contract negotiation.

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
