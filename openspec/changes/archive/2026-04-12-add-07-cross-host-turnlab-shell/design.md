## Context
The deterministic harness currently binds and advertises `127.0.0.1` for TURN UDP, TURN TCP, and peer endpoints.
Windows GUI testing from WSL needs a harness that can still run inside Linux while advertising addresses reachable from the Windows host.

## Goals
- Preserve the current loopback-only default for existing tests and local CLI workflows.
- Allow harness listeners to bind on one address while publishing a different address in the descriptor and `generic-turn` links.
- Provide one obvious `cmd/turnlab-shell` path for Windows GUI testing from WSL.

## Non-Goals
- Rework the harness into a general remote lab service.
- Change the `generic-turn` provider contract.
- Guarantee reachability across arbitrary NAT or firewall boundaries.

## Decisions
- Extend `turnlab.Options` with separate bind and advertise addresses for TURN and peer publication.
- Continue to keep the upstream echo path local-only; only TURN and peer endpoints need cross-host reachability.
- Add a `-windows-gui` convenience flag to `cmd/turnlab-shell` that auto-selects a non-loopback IPv4 address and uses it for both bind and advertise values.
- Keep advanced `-bind-address` and `-advertise-address` flags for deterministic manual runs and tests.

## Risks / Trade-offs
- Auto-detecting a non-loopback address can pick the wrong interface on unusual hosts.
  Mitigation: explicit `-bind-address` and `-advertise-address` flags override the convenience mode.
- Publishing an advertised address different from the actual bind address complicates cleanup-oriented reasoning.
  Mitigation: preserve existing default mode and cover split bind/advertise behavior with targeted tests.
