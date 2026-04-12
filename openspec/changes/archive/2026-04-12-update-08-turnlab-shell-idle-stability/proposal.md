# Change: [08] Stabilize turnlab shell idle window for desktop GUI testing

## Why
The diagnostics bundle `086ac01789eaf5aa037fa8a0648d1835-2026-04-05T18-45-04.039397Z.json` shows a Windows desktop GUI session against a WSL-hosted `turnlab-shell` reaching `session_ready` at `2026-04-05T18:44:45.886528Z`, then entering `session_retrying` at `2026-04-05T18:44:50.886699Z`, and finally failing with `worker 0 exhausted restart budget after 1 restart(s): stage forwarding_loop failed: read relay datagram: EOF`.

That five-second gap matches the current harness peer idle timeout, which is acceptable for deterministic tests but too short for manual desktop GUI runs where an operator needs time to inspect the UI before sending traffic.

## What Changes
- Add configurable peer idle timeout support to the turnlab harness.
- Make `cmd/turnlab-shell` use a manual-friendly idle window so desktop GUI sessions do not die immediately after reaching `ready`.
- Keep deterministic short-idle behavior available for automated tests and explicit lab runs.
- Document the manual shell idle behavior and override flags.

## Impact
- Affected specs: `turn-lab-harness`
- Affected code: `test/turnlab`, `cmd/turnlab-shell`, `README.md`, harness and shell tests
