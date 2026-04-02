# ADR 0001: Canonical Go Monorepo

## Status

Accepted

## Context

The reference implementation is working but hard to evolve safely:
- provider-specific code is mixed with transport and orchestration
- there is no reliable compatibility harness
- there are multiple repositories and ad hoc implementations

We need one canonical repository that can be maintained iteratively without a big-bang rewrite.

## Decision

We will build the canonical repository in Go as a single monorepo with these boundaries:
- `internal/provider/*` for provider-specific signaling and credential resolution
- `internal/transport/*` for provider-agnostic transport primitives
- `internal/session` for orchestration and lifecycle
- `cmd/*` for operational binaries

The legacy repository remains the compatibility oracle until equivalent coverage exists here.

## Consequences

Positive:
- fastest path to a maintainable product baseline
- compatible with the current working reference implementation
- simpler CI, packaging, and cross-compilation story

Negative:
- Go is not a fresh clean slate unless architectural boundaries are enforced
- legacy compatibility still needs explicit tests and fixtures

