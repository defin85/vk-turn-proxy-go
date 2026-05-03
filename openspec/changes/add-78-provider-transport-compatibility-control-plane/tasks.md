## 1. Control-plane model

- [x] 1.1 Add provider/transport compatibility DTOs in `pkg/clientcontrol`
      for source/artifact references, selected transport profile references,
      runtime execution plan identity, support state, failing axis, and reason.
- [x] 1.2 Add host capability metadata for the compatibility read model so
      updated shells fail closed against older hosts.
- [x] 1.3 Preserve unknown future provider source ids, carrier families,
      engine families, host adapters, and profile kinds as typed string values
      instead of dropping the response.
- [x] 1.4 Define stable compatibility status, failing-axis, and reason-code
      enums, and make unknown values fail closed in shell-facing helpers.

## 2. Compatibility evaluator

- [x] 2.1 Implement a host-owned evaluator that combines provider/source or
      resolved artifact state, runtime execution plans, host adapter support,
      required profile kind, and selected VPN transport profile status.
- [x] 2.2 Return typed statuses for startable, setup-needed, unsupported,
      stale, degraded, and missing-evidence combinations.
- [x] 2.3 Return failing-axis metadata that tells the shell whether to guide the
      operator to provider setup, source resolution, profile setup, host
      capability, degraded-policy approval, or evidence collection.
- [x] 2.4 Keep explicit selected/default transport profile semantics; do not
      infer startup selection from compatible, last edited, imported, or
      displayed profiles.

## 3. Startup validation

- [x] 3.1 Extend platform-tunnel startup validation so requests that use both
      axes carry explicit source/resolution/artifact and transport-profile
      references.
- [x] 3.2 Revalidate the exact source/artifact, execution plan, and transport
      profile combination at startup.
- [x] 3.3 Fail closed with typed axis/reason metadata when the read-model
      candidate becomes stale before startup.

## 4. Tests and verification

- [x] 4.1 Add Go tests for a startable existing Generic TURN plus
      `wireguard_native_v1` combination.
- [x] 4.2 Add Go tests for missing profile, incompatible profile kind, stale
      provider resolution, unsupported engine/carrier, and degraded or
      missing-evidence candidates.
- [x] 4.3 Add Go tests proving unknown compatibility status or failing-axis
      values are non-startable for older shells.
- [x] 4.4 Add regression coverage proving no implicit selection of most-recent
      compatible transport profile.
- [x] 4.5 Run
      `openspec validate add-78-provider-transport-compatibility-control-plane --strict --no-interactive`.
- [x] 4.6 Run `openspec validate --all --strict --no-interactive`.
- [x] 4.7 Run `git diff --check`.
