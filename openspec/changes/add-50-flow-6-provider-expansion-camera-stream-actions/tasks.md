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

## 4. Research carry-forward
- [ ] 4.1 Preserve the current live evidence that researched camera providers
      may still be navigation-first only: browser `fMP4` viewer paths, native
      `spif2-proto` cloud playback, and `p2p_mode=false` on both same-LAN and
      mobile uplinks.
- [ ] 4.2 Before proposing same-device playback or transport reuse, test
      whether blocking the provider cloud media contour while keeping ordinary
      account access alive can force a typed local or P2P continuation.
- [ ] 4.3 If a provider-selected local or P2P same-device path appears,
      capture it as a separate family-specific executor follow-up with live
      verification instead of widening the generic camera action contract.
