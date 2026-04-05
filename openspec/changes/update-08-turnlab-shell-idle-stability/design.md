## Context
`test/turnlab` currently hardcodes a five-second peer idle timeout.
That is useful for fast deterministic cleanup in tests, but it is hostile to manual desktop GUI workflows where the operator may wait several seconds after `ready` before sending a probe.

## Goals
- Preserve deterministic harness behavior for automated tests.
- Prevent `cmd/turnlab-shell` from dropping an otherwise healthy desktop GUI session during the initial manual inspection window.
- Make the idle policy explicit and configurable.

## Non-Goals
- Change live provider runtime supervision policy.
- Add generic TURN keepalive behavior to the client runtime.
- Turn `turnlab-shell` into a production relay service.

## Decisions
- Extend the harness options with a configurable peer idle timeout.
- Keep the harness library default at the current short deterministic value unless the caller opts into a different timeout.
- Make `cmd/turnlab-shell` choose a longer default idle timeout for manual operator workflows.
- Add an explicit shell flag so manual runs can shorten or extend the idle window deliberately.

## Risks / Trade-offs
- A longer idle timeout in the shell means slower cleanup if an operator forgets to stop the harness.
  Mitigation: limit the change to `cmd/turnlab-shell` defaults and keep test callers explicit.
- If the timeout is increased too aggressively, manual failures may take longer to surface.
  Mitigation: keep the timeout operator-friendly but bounded, and allow explicit override.
