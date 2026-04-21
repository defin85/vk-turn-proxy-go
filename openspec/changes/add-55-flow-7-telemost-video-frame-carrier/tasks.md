## 1. Carrier contract
- [ ] 1.1 Add the new `webrtc-video-frame-carrier` capability for the first
      repo-owned video-frame same-device execution path.
- [ ] 1.2 Define the execution tuple explicitly as
      `webrtc_call_attach + webrtc_video_frames + custom_packet_overlay +
      webrtc_call_endpoint`.
- [ ] 1.3 Keep the path experimental, non-default, and fail-closed until
      release verification proves real payload traffic.

## 2. Artifact and control-plane deltas
- [ ] 2.1 Extend provider/runtime artifact requirements so only eligible
      attachable conference artifacts may advertise the video-frame path.
- [ ] 2.2 Extend the client control plane contract for explicit negotiation,
      startup, and typed failure reporting of the video-frame path.
- [ ] 2.3 Keep attach or bootstrap material inside the host boundary and out of
      ordinary reads.

## 3. Evidence boundary
- [ ] 3.1 Define the evidence bar for readiness so room join, track publish, or
      frame pump alone do not count as runtime success.
- [ ] 3.2 Define fail-closed handling for missing attach target, missing frame
      publisher, or missing runtime prerequisites.

## 4. Validation
- [ ] 4.1 Run
      `openspec validate add-55-flow-7-telemost-video-frame-carrier --strict --no-interactive`
