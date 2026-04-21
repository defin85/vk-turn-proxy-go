## 1. Contract
- [ ] 1.1 Add a `smarthome-provider` capability for the provider descriptor,
      typed entry contract, redacted ordinary reads, and fail-closed behavior.
- [ ] 1.2 Bind successful `smarthome` resolution to the `camera_stream`
      artifact family and the committed camera-stream action surface.
- [ ] 1.3 Keep local media playback, conference actions, and `generic-turn`
      export out of scope.

## 2. Evidence and rollout
- [ ] 2.1 Require descriptor and shell rollout to stay behind the flow-6
      shipping gate until `smarthome`-specific evidence exists.
- [ ] 2.2 Define fail-closed handling for blocked, incomplete, or unsupported
      camera/device flows.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-52-flow-6-provider-expansion-smarthome-provider --strict --no-interactive`
