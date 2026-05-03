## Context

The repository already models execution as typed plans, but it still treats
same-device startup as selecting one plan and one carrier for one runtime
attempt.

That leaves a gap between today's single-path runtime and a future
multitransport product:

- there is no typed pathset object
- there is no explicit failover scheduler
- there is no honest boundary between failover and bandwidth aggregation
- there is no explicit way to say that two child paths share the same
  provider-side throughput ceiling

This change exists to close only that first gap.

## Goals

- Define one explicit pathset contract for multitransport runtime.
- Keep the first scheduler narrow as `active_standby`.
- Preserve explicit child-plan truth and fail-closed compatibility gates.
- Distinguish independent transport limit domains from same-provider fan-out.

## Non-Goals

- Packet striping across paths.
- Aggregate bandwidth claims.
- Generic support for every possible heterogeneous carrier mix.

## Decisions

### Decision: Pathsets compose existing child execution plans

The first multitransport slice should not invent a new "super plan" that hides
its children. It should compose already documented execution plans into a
pathset.

### Decision: The first scheduler is failover-oriented, not bandwidth-oriented

`active_standby` keeps one path active and the others warm or eligible for
promotion. That is operationally simpler and does not overclaim throughput.

### Decision: Compatibility stays explicit

The host should reject unsupported path combinations before startup instead of
guessing that any two individually valid plans are also safe together.

### Decision: Pathsets carry limit-domain truth

A pathset must not use child-count as a proxy for transport diversity. If two
child plans share the same provider, call, TURN allocation policy, traffic
class, or another documented throttling domain, the host may still use them for
failover, but support wording and diagnostics must not imply additive
bandwidth.
