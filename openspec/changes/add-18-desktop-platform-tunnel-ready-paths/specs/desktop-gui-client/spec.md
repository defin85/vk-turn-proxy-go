## ADDED Requirements
### Requirement: Desktop GUI system tunnel support remains explicit, host-driven, and target-specific

The system SHALL keep desktop GUI system tunnel support explicit and host-driven instead of implying it from package installation, OS heuristics, or one other desktop target's delivery status.
Installing the desktop app SHALL NOT silently claim desktop-wide system traffic capture support, but the GUI MAY offer the documented system tunnel workflow for the packaged target and mode that the bundled host explicitly reports as supported.

#### Scenario: Desktop package still lacks a supported platform tunnel mode

- **GIVEN** a desktop package whose connected host does not report a supported platform tunnel mode for that packaged target
- **WHEN** the operator inspects platform support in the desktop GUI shell
- **THEN** the GUI reports that repo-owned system tunnel support is not yet available for that target
- **AND** it does not silently redefine the external `WireGuard for Windows` compatibility workflow or some other target's support claim as the same capability

#### Scenario: Packaged Windows host reports a supported `windows_wintun` mode

- **GIVEN** a production Windows desktop package whose bundled host reports `windows_wintun` as a supported platform tunnel mode
- **WHEN** the operator inspects platform support in the desktop GUI shell
- **THEN** the GUI offers the documented Windows system tunnel workflow for that mode
- **AND** it uses the typed startup result instead of guessing support from OS heuristics, package presence, or manual route instructions alone
