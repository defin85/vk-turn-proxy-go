# Change: [50] Add flow-6 provider expansion camera stream actions

## Why
The current live contract already names `camera_stream` as a distinct artifact
family, but it does not yet commit the first ordinary action surface for that
family.

That gap blocks honest camera-style providers. Without one typed action
contract, the first camera provider rollout would either flatten camera access
into a fake conference or tunnel model, or force provider-specific raw payload
handling back into the shells.

Flow-6 needs one generic camera-stream action surface before a provider such as
`smarthome` can be added honestly.

## Sequence
- Order: `50`
- Depends on: `add-20-multi-provider-runtime-families`,
  `add-48-flow-6-provider-expansion-shipping-gates`
- Unblocks: `add-52-flow-6-provider-expansion-smarthome-provider`

## What Changes
- Add a `camera-stream-actions` capability that defines the typed ordinary
  summary and machine-readable post-resolution actions for `camera_stream`
  artifacts.
- Standardize the first camera-stream action surface around explicit
  shell-external navigation such as `open_camera` and optional `open_archive`.
- Define how desktop and mobile shells present camera artifacts without
  pretending that the tunnel runtime or a local media executor already exists.
- Keep same-device playback execution out of scope until a later change adds a
  real family-specific executor.

## Impact
- Affected specs: `camera-stream-actions` (new)
- Affected code: `pkg/clientcontrol`, host resolution/event models, desktop and
  mobile shell action surfaces, provider-facing docs

## Assumptions
- The first committed camera-stream action is `open_camera`, with
  `open_archive` optional when the provider exposes a real archive target.
- The product should not claim local camera playback, conference attach, or
  tunnel semantics for `camera_stream` artifacts in this slice.
- Provider-specific player or stream tokens must remain redacted in ordinary
  reads.

## Current Research Status
- Live `smarthome` research on May 6-8, 2026 confirmed that the current web
  and native product surfaces both fit `camera_stream` rather than
  `conference_room` or `generic_turn`.
- Browser evidence showed an account-bound camera page under
  `lk.smarthome.rt.ru/devices/{id}`, `blob:` playback with `srcObject = null`,
  and a provider-owned media websocket on
  `wss://live-msk2.camera.rt.ru/stream/.../live.mp4` carrying `fMP4`-style
  fragments and related player control traffic.
- Native Android evidence showed `ru.rt.smarthome` using `VCKIT-SESSION` and
  `VCKIT-STREAM_SPIF`, upgrading `https://live-msk2.camera.rt.ru/blue7` to
  `spif2-proto`, and resolving the same camera with `p2p_mode=false` on both
  same-LAN Wi-Fi and mobile uplinks.
- A local camera host at `192.168.0.14` exposed authenticated RTSP on `:554`,
  but the current provider-owned product flows did not expose reusable local
  playback credentials, typed local continuation, or usable arbitrary-payload
  transport.
- Therefore `open_camera` and optional `open_archive` remain the only honest
  committed actions in this slice.

## Further Actions
- Test whether the provider ever emits `p2p_mode=true` or another typed local
  or P2P continuation when the cloud media contour is unavailable while the
  operator still has ordinary account access.
- Treat any future `SPIF`, RTSP, or provider-specific P2P same-device path as
  a separate family-specific executor follow-up rather than as an implicit
  expansion of this generic camera action contract.
- Keep internet egress, arbitrary payload transport, and same-device camera
  playback out of scope until that follow-up has explicit contract text, code,
  and live verification evidence.
