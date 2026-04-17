## 1. State and Model
- [x] 1.1 Add a shell-owned mobile user-template entity and persistence path
  alongside managed providers in local mobile shell state.
- [x] 1.2 Keep user-template contents limited to reusable non-secret
  provider-owned values using the same descriptor-driven normalization rules as
  managed providers.
- [x] 1.3 Add controller operations to create, edit, delete, select, and use
  user templates without disturbing provider-family taxonomy or existing
  managed-provider snapshot behavior.

## 2. Provider Workflow
- [x] 2.1 Add `Save as template` from the provider draft or saved provider
  editor.
- [x] 2.2 Add a dedicated user-template editing path that reuses the provider
  field surface with template-specific actions and copy.
- [x] 2.3 Update the mobile template chooser so it distinguishes `My templates`
  from shipped templates while keeping shipped templates read-only.
- [x] 2.4 Keep `Use template` seeding a new managed provider draft instead of
  editing an existing saved provider in place.

## 3. Validation
- [x] 3.1 Add or update widget coverage for user-template create, use, edit,
  delete, and shipped-template read-only behavior.
- [x] 3.2 Run `cd mobile/gui_shell && flutter analyze`.
- [x] 3.3 Run `cd mobile/gui_shell && flutter test test/widget_test.dart`.
- [x] 3.4 Run `openspec validate add-35-mobile-user-provider-templates --strict --no-interactive`.
- [x] 3.5 Validate the user-template workflow manually on a mobile device or
  emulator for compact and wide layouts.
  Wide and compact Android validation completed on 2026-04-17 via Dart MCP
  driver mode. Wide verification covered `Save as template`, `Edit template`,
  and `My templates` vs `Shipped templates`. Compact verification covered the
  bottom-nav compact layout, drill-down into provider and template editors, and
  `Back to providers` returning to the list-first root.
