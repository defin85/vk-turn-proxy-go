## 1. Contract
- [ ] 1.1 Add a `vk-multi-allocation-runtime` capability for same-provider,
      same-tuple multiple TURN allocations under one logical VK runtime
      session.
- [ ] 1.2 Define the first VK multi-allocation scheduler as explicit
      `active_standby` instead of generic worker fan-out.
- [ ] 1.3 Require one successful VK provider resolution to feed the requested
      active plus standby allocation count without implying additive bandwidth.
- [ ] 1.4 Record that VK TURN connection count is not a throughput multiplier
      unless fresh live evidence proves scaling for the selected contour.

## 2. Runtime behavior
- [ ] 2.1 Extend `tunnel-client-runtime` so the explicit VK
      `active_standby` policy keeps one payload path active and one or more
      same-tuple standby allocations ready for promotion.
- [ ] 2.2 Define fail-closed startup behavior when the requested standby count
      cannot be established because of allocation quota, capacity, or another
      transport-stage failure.
- [ ] 2.3 Define standby-promotion semantics so the runtime does not pretend
      that multiple allocations were carrying the same payload concurrently
      before promotion.
- [ ] 2.4 Surface degraded-throughput status without promoting standby
      allocations into an active-active bandwidth mode.

## 3. Compatibility and verification
- [ ] 3.1 Extend `vk-runtime-compatibility` with explicit evidence for standby
      promotion under one VK session.
- [ ] 3.2 Extend `vk-runtime-compatibility` with explicit evidence for
      allocation-quota or partial-bring-up failure without silent degradation.
- [ ] 3.3 Keep operator-facing support wording scoped to resilience and
      failover, not aggregate throughput.
- [ ] 3.4 Add compatibility evidence comparing one versus multiple VK
      connections/allocations so non-scaling contours are recorded as degraded
      rather than treated as successful bandwidth recovery.

## 4. Validation
- [ ] 4.1 Run
      `openspec validate add-60-vk-multi-allocation-active-standby --strict --no-interactive`
