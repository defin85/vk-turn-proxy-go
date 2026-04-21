## 1. Research boundary
- [ ] 1.1 Add a `packet-striping-runtime-research` capability that keeps
      packet striping out of shipped support until a later reviewed
      implementation change lands.
- [ ] 1.2 Define the minimum design prerequisites for striping readiness:
      global ordering, reorder handling, duplicate suppression, and congestion
      strategy.
- [ ] 1.3 Define kill criteria so throughput anecdotes or one-off demos do not
      count as product readiness.

## 2. Evidence posture
- [ ] 2.1 Define the evidence required before the repository may claim
      packet-striping support.
- [ ] 2.2 Keep packet striping separate from `active_standby` and
      `flow_sharded` support claims.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-59-flow-8-multitransport-packet-striping-research --strict --no-interactive`
