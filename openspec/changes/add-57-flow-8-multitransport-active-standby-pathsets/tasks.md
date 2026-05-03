## 1. Contract
- [ ] 1.1 Add a `multi-transport-runtime-pathsets` capability for one logical
      runtime session backed by an ordered set of child execution plans.
- [ ] 1.2 Define the first scheduler as `active_standby` and keep child plans
      explicit instead of collapsing them into one opaque mode string.
- [ ] 1.3 Keep packet striping and aggregate bandwidth claims explicitly out of
      scope.
- [ ] 1.4 Define failure/limit-domain metadata so same-provider fan-out is not
      mistaken for bandwidth-diverse multitransport.

## 2. Runtime behavior
- [ ] 2.1 Define path-health, failover, and readiness semantics for one active
      path plus one or more standby paths.
- [ ] 2.2 Define compatibility gates so unsupported child-plan mixes fail
      closed before runtime startup.
- [ ] 2.3 Define degraded-throughput handling as a health input without turning
      `active_standby` into an aggregate-throughput scheduler.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-57-flow-8-multitransport-active-standby-pathsets --strict --no-interactive`
