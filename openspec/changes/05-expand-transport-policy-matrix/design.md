## Context

The base runtime change deliberately supports only one narrow startup policy so the first end-to-end path can land safely.
The repository still exposes transport controls in config and CLI, and the product contract expects those controls to become real behavior.

## Goals

- Support explicit TURN transport selection where declared by config.
- Support DTLS-on and DTLS-off client runtime paths explicitly.
- Respect interface pinning for outbound transport setup when configured.

## Non-Goals

- Introducing multi-connection supervision in the same change.
- Adding new providers.
- Hiding unsupported combinations behind auto-fallback behavior.

## Decisions

- `mode=udp` uses UDP to the TURN server; `mode=tcp` uses TCP to the TURN server; `mode=auto` resolves to the documented default for the provider/runtime slice.
- `dtls=false` runs a provider-agnostic plain transport path instead of silently forcing DTLS on.
- `bind-interface` applies to outbound transport setup and must fail explicitly when the requested interface or address cannot be used.
- Each newly supported combination must have targeted integration coverage; unsupported combinations continue to fail closed until specified.

## Risks / Trade-offs

- Supporting more policy combinations increases the test matrix quickly.
  Mitigation: expand the matrix in one explicit change with documented supported cases.
- Interface pinning behavior can be platform-sensitive.
  Mitigation: keep the contract narrow and prefer deterministic tests for parser/plumbing plus targeted integration tests where feasible.

## Migration Plan

1. Define the expanded policy matrix explicitly.
2. Implement the additional runtime paths and interface plumbing.
3. Add matrix tests and document the supported combinations.
