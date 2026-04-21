## 1. Evidence contract
- [ ] 1.1 Add a `telemost-release-verification` capability for repo-owned live
      evidence and support-promotion rules.
- [ ] 1.2 Define separate verification requirements for shell-external room
      opening and any same-device Telemost runtime tuple.
- [ ] 1.3 Keep community PoCs, browser-only success, and anecdotal throughput
      numbers explicitly non-authoritative for shipped support claims.

## 2. Promotion rules
- [ ] 2.1 Define how Telemost may be promoted in slices without implying that
      unverified surfaces are also supported.
- [ ] 2.2 Define the evidence required for same-device Telemost runtime claims,
      including attach readiness, payload traffic over the documented carrier,
      and fail-closed behavior on expiry or missing prerequisites.
- [ ] 2.3 Define how the repository records Telemost as legacy, experimental,
      or supported without overstating current readiness.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-56-flow-7-telemost-release-verification --strict --no-interactive`
