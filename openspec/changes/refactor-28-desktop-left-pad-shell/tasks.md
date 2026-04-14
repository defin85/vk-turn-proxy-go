## 1. Implementation

- [ ] 1.1 Introduce an explicit desktop canvas-route model that is separate
      from workflow selection and inspector state.
- [ ] 1.2 Replace the current left-side summary/card stack with a compact
      left pad for workflow switching, task entry, and active selection cues.
      Do not keep a separate persistent action/explanation card above the
      active canvas route for routine task entry.
- [ ] 1.3 Move saved-profile browsing into a dedicated main-canvas picker route
      with an explicit back path.
- [ ] 1.4 Move managed-provider browsing and provider-family selection into
      dedicated main-canvas routes instead of modal-first surfaces.
- [ ] 1.5 Move preset bootstrap into a dedicated main-canvas picker route
      instead of an inline or modal companion surface.
- [ ] 1.6 Remove persistent "Current focus", "Current task", and similar
      duplicated summary-card blocks from the default desktop shell, along with
      large route-restating action cards above the active editor.
- [ ] 1.7 Keep diagnostics/live work secondary through the inspector and ensure
      the header remains compact in ready state.
- [ ] 1.8 Update desktop widget coverage for canvas-route entry/exit,
      draft-preservation, active-selection continuity, explicit in-canvas back
      navigation, and inspector behavior.
- [ ] 1.9 Refresh desktop shell docs/reference assets to match the new left-pad
      interaction model.
      Acceptance gate: the default ready-state shell must read as `left pad +
      one dominant canvas + optional inspector`, not as several equal-weight
      card regions.
