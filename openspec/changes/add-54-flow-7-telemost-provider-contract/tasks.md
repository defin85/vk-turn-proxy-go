## 1. Provider contract
- [ ] 1.1 Add a `telemost-provider` capability for the
      `yandex-telemost` descriptor, entry contract, and fail-closed behavior.
- [ ] 1.2 Bind successful Telemost resolution to the `conference_room`
      artifact family and the committed conference-room action surface.
- [ ] 1.3 Keep `generic_turn` export and same-device Telemost attach out of
      scope unless a separate approved artifact or carrier contract exists.

## 2. Entry posture
- [ ] 2.1 Define Telemost auth posture explicitly, including the separation
      between room creation/bootstrap and join/runtime prerequisites.
- [ ] 2.2 Define Telemost browser or continuation posture explicitly so shells
      do not guess whether embedded, external, guest, or account-backed entry
      is valid.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-54-flow-7-telemost-provider-contract --strict --no-interactive`
