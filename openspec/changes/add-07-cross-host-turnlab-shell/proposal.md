# Change: [07] Add cross-host turnlab shell mode

## Why
`cmd/turnlab-shell` currently prints loopback-only TURN and peer addresses from the local harness.
That works for same-host CLI and tests, but it fails when a Windows desktop GUI tries to consume a harness started inside WSL because the advertised TURN and peer endpoints remain `127.0.0.1`.

## What Changes
- Add a cross-host harness mode that separates listener bind addresses from advertised TURN and peer addresses.
- Add a Windows-GUI-friendly `turnlab-shell` mode that prints desktop-consumable `generic-turn` and peer values instead of loopback-only values.
- Keep the existing loopback default unchanged for deterministic same-host tests.

## Impact
- Affected specs: `turn-lab-harness`
- Affected code: `test/turnlab`, `cmd/turnlab-shell`, `README.md`, harness tests
