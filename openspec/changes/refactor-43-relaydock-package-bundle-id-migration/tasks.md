## 1. Identity contract
- [x] 1.1 Define the canonical RelayDock package/bundle/application identifier
      set for Android, iOS, macOS, and Linux plus the dedicated repo-managed
      publish-identity manifest that owns those values.
- [x] 1.2 Define the explicit non-goals for this migration so internal Dart
      package names, artifact-role strings, and shell state directory roots do
      not drift into the same rollout by accident.

## 2. Native project migration
- [x] 2.1 Migrate Android `applicationId`, namespace, Kotlin package paths,
      manifest-owned components, and package-oriented automation/docs to the
      canonical RelayDock mobile identifier.
- [x] 2.2 Migrate iOS and macOS Runner bundle identifiers, related test-target
      identifiers, and project metadata to the canonical RelayDock publish
      identifiers.
- [x] 2.3 Migrate Linux application identifiers and desktop-integration
      metadata to the canonical RelayDock desktop identifier, and align the
      packaged Linux desktop binary stem with the same desktop publish identity
      without renaming Dart package or artifact-role identifiers in the same
      pass.
- [x] 2.4 Migrate macOS bundled app output naming, test-host references,
      Windows packaged executable metadata, and repo-owned desktop launch or
      staging helpers to the canonical RelayDock desktop native output names
      where they still expose legacy shell output stems.

## 3. Build and migration safeguards
- [x] 3.1 Update repo-owned build workflows and verification to read
      publish-facing identifiers from the canonical identity source and fail on
      mixed legacy publish-facing identifiers such as
      `com.defin85.mobile_gui_shell`, `com.defin85.gui_shell`, or example
      bundle IDs where this change applies, without treating internal
      out-of-scope names such as Dart package names, artifact-role strings, or
      shell state directory roots as migration failures.
- [x] 3.2 Update runbooks, smoke automation, and debug helpers to use the
      canonical RelayDock package/bundle IDs, with explicit legacy cleanup
      guidance where package migration cannot happen in place.
- [x] 3.3 Document the supported mobile continuity boundary for shell-owned
      state and secrets across the publish-identity cutover, and do not claim a
      seamless in-place upgrade unless a reviewed migration path is actually
      implemented.

## 4. Verification
- [x] 4.1 Add or update targeted checks that prove the migrated native
      projects, repo-owned automation, and desktop native output-name surfaces
      no longer depend on the legacy publish-facing package/bundle identifiers
      or legacy shell output stems covered by this change.
- [x] 4.2 Run `openspec validate refactor-43-relaydock-package-bundle-id-migration --strict --no-interactive`.
