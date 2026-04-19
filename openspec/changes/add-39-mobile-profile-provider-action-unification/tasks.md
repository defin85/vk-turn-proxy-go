## 1. Action Model
- [x] 1.1 Add an explicit mobile action model for `Profiles` and `Providers`
  with root command surfaces above the primary record lists.
- [x] 1.2 Implement a selection-aware root action row for focused record
  actions and do not add a second detail-header action cluster.
- [x] 1.3 Split current-profile targeting from detail/edit selection so opening
  a profile does not implicitly retarget `Home`.
- [x] 1.4 Add persisted-state and restore semantics for separate current-profile
  targeting and focused profile/detail selection.
- [x] 1.5 Add controller operations for duplicating a saved profile, managed
  provider, and user template by snapshot copy.

## 2. Profiles Workflow
- [x] 2.1 Move portable profile import and export entry points to the `Profiles`
  root surface while preserving explicit preview and confirmation behavior.
- [x] 2.2 Add root- or detail-level profile actions for `Edit`, `Copy`,
  `Delete`, and `Make current`.
- [x] 2.3 Keep the profile editor footer limited to save plus start-or-resolve
  actions and remove secondary entity actions from that footer.

## 3. Providers Workflow
- [x] 3.1 Add first-class `Saved providers` and `Templates` surfaces within the
  `Providers` workflow.
- [x] 3.2 Add root- or detail-level managed-provider actions for `Copy`, `Use
  in profile`, `Save as template`, and `Delete`.
- [x] 3.3 Add root- or detail-level template actions for `Use`, `Copy`, `Edit`,
  and `Delete`.
- [x] 3.4 Keep provider-family and shipped-preset discovery in the create flow
  while removing user-template management from that flow.

## 4. Validation
- [x] 4.1 Add or update widget coverage for the new profile and provider action
  surfaces, including copy actions and root-level profile transfer.
- [x] 4.2 Add or update controller coverage for duplicate semantics and the
  split between current profile and detail focus.
- [x] 4.3 Run `cd mobile/gui_shell && flutter analyze`.
- [x] 4.4 Run targeted `flutter test` coverage for `widget_test.dart` and
  `mobile_shell_controller_test.dart`.
- [x] 4.5 Run `openspec validate add-39-mobile-profile-provider-action-unification --strict --no-interactive`.
- [x] 4.6 Validate the resulting compact and wide mobile workflows manually on a
  physical device or emulator.
