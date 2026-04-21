## 1. Contract
- [ ] 1.1 Add a `camera-stream-actions` capability for redacted
      `camera_stream` summary fields and stable machine-readable actions.
- [ ] 1.2 Define `open_camera` as the first committed camera-stream action and
      keep unsupported same-device playback fail-closed.
- [ ] 1.3 Define how optional archive access is exposed through a stable typed
      action instead of provider-specific shell parsing.

## 2. Shell behavior
- [ ] 2.1 Define desktop and mobile camera-stream action surfaces without
      provider-name branching.
- [ ] 2.2 Keep camera-stream artifacts separate from conference-room, tunnel,
      and fake local-player semantics.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-50-flow-6-provider-expansion-camera-stream-actions --strict --no-interactive`
