## Context

The current provider story is live-VK-first. That is useful for real acceptance, but it is a poor default for deterministic tests and local operator workflows.
The provider matrix already marks `generic-turn` as a planned provider for lab and integration scenarios.

## Goals

- Provide a deterministic provider-backed credential source for tests and lab runs.
- Keep the provider API identical to other adapters: `Resolve(context.Context, link)`.
- Fail closed on malformed static credential links.

## Non-Goals

- Secret storage, secret rotation, or external config backends.
- Replacing live-provider acceptance for VK.
- Supporting provider-specific session signaling beyond static TURN credentials.

## Decisions

- Define the link format as `generic-turn://<username>:<password>@<host>:<port>`.
- Normalize the resolved TURN address to `host:port`, matching the existing provider contract.
- Return a sanitized artifact with `resolution_method=static_link` and redacted username/password placeholders so probe workflows stay consistent.
- Reject missing username, missing password, missing host, or missing port with explicit parse errors before any transport startup.

## Alternatives Considered

- Put static TURN credentials directly into client flags.
  Rejected because it would bypass the provider boundary and make runtime tests/provider tests diverge.
- Use environment variables instead of a provider link.
  Rejected because the repository already models credential resolution through a single `link` input.

## Risks / Trade-offs

- URLs with embedded credentials are sensitive.
  Mitigation: redact credentials in artifacts and never echo the raw link in normal probe output.
- The static provider could become an accidental production path.
  Mitigation: document it as a lab/debug provider and keep the name explicit.

## Migration Plan

1. Add the provider adapter and link parser.
2. Register it in provider-consuming binaries.
3. Add unit tests and probe acceptance tests.
4. Use it as the deterministic provider for later transport/runtime changes.
