## 1. Contract
- [ ] 1.1 Add a `conference-room-actions` capability for redacted
      `conference_room` summary fields and stable machine-readable actions.
- [ ] 1.2 Define `open_room` as the first committed conference-room action and
      keep unsupported same-device execution fail-closed.
- [ ] 1.3 Define action-ownership and navigation-target rules for ordinary
      reads and events.

## 2. Shell behavior
- [ ] 2.1 Define desktop and mobile conference-room action surfaces without
      provider-name branching.
- [ ] 2.2 Keep conference-room artifacts separate from tunnel startup,
      `generic-turn` export, and fake local-runtime claims.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-49-flow-6-provider-expansion-conference-room-actions --strict --no-interactive`
