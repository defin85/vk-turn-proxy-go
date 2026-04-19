## ADDED Requirements

### Requirement: Resolution-backed platform-tunnel startup uses the ordinary runtime session surface

The system SHALL keep resolution provenance and runtime lifecycle distinct even
when a successful same-device startup path uses a packaged platform tunnel.

#### Scenario: Resolution-backed platform tunnel publishes an ordinary session

- **GIVEN** a successful provider resolution record that supports same-device
  startup
- **AND** the chosen runtime path is a supported packaged platform-tunnel mode
- **WHEN** the host reaches runtime-backed ready state for that startup
- **THEN** the host publishes the resulting runtime as an ordinary typed
  session
- **AND** that session links back to the originating resolution
- **AND** the operator does not need a separate tunnel-only runtime surface to
  understand that same-device startup succeeded
