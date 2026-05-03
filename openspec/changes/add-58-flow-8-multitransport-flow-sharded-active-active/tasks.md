## 1. Contract
- [ ] 1.1 Add a `flow-sharded-runtime-execution` capability for active-active
      pathsets that distribute flows across child paths.
- [ ] 1.2 Define the first concurrent scheduler as `flow_sharded`.
- [ ] 1.3 Keep packet-level striping explicitly out of scope.
- [ ] 1.4 Require limit-domain and path-score evidence before claiming
      flow-sharded throughput aggregation.

## 2. Scheduler behavior
- [ ] 2.1 Define stable flow-to-path ownership and failover behavior for
      affected flows when one child path degrades or fails.
- [ ] 2.2 Define what counts as a flow for datagram and stream-style runtime
      traffic.
- [ ] 2.3 Keep rebalance and path-selection rules explicit rather than
      heuristic.
- [ ] 2.4 Define behavior when child paths share one observed throughput
      ceiling: no aggregate-throughput claim, even if concurrent flows run.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-58-flow-8-multitransport-flow-sharded-active-active --strict --no-interactive`
