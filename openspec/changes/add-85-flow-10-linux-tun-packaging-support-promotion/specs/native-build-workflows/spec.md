## ADDED Requirements
### Requirement: Repository provides a packaged Ubuntu desktop install path for `linux_tun`

The repository SHALL provide a documented, repo-owned install or packaging
entrypoint for the first supported Ubuntu `linux_tun` desktop target instead of
treating a hand-copied bundle as the support surface.

#### Scenario: Operator prepares the supported Ubuntu desktop package

- **GIVEN** the repository promotes one supported Ubuntu desktop `linux_tun`
  target
- **WHEN** the operator runs the documented Linux packaging or install
  entrypoint
- **THEN** the workflow stages the desktop bundle together with the Linux
  helper and its required privilege-mediation metadata
- **AND** the staged output is the documented source of truth for the supported
  Ubuntu install surface
- **AND** packaged startup does not depend on ad hoc manual helper placement
