## Context

The repository already emits structured logs through `internal/observe`, but there is no explicit observability contract for real runtime behavior.
Without that contract, transport debugging and operational acceptance will stay ad hoc as soon as sessions become long-lived.

## Goals

- Emit structured runtime events with stable field names.
- Expose metrics for the most important session and transport outcomes.
- Keep provider-sensitive data redacted in logs and metrics labels.

## Non-Goals

- Full distributed tracing infrastructure.
- Per-packet logging.
- Provider-specific metrics that leak invite tokens or credential material.

## Decisions

- Keep log events structured and tied to session identifiers, provider name, runtime stage, and transport policy.
- Expose metrics through a documented endpoint or runtime surface for long-lived binaries.
- Track at least session starts, session failures, active workers, startup-stage failures, and forwarded bytes/packets.
- Apply the same redaction expectations to observability output as to probe artifacts.

## Risks / Trade-offs

- Metrics can create extra runtime surface area and configuration.
  Mitigation: keep the first contract small and focused on actionable runtime signals.
- Overly detailed labels can leak sensitive provider data or explode cardinality.
  Mitigation: restrict labels to low-cardinality runtime dimensions and redact provider secrets.

## Migration Plan

1. Define the runtime event schema and minimal metric set.
2. Instrument client/server/runtime code paths.
3. Add tests or snapshots for key observability outputs.
4. Document how operators consume the signals.
