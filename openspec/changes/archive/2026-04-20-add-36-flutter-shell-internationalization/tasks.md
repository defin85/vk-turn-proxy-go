## 1. Shared i18n foundation

- [x] 1.1 Add a shared workspace package for shell localization and document the
      repo-owned generation workflow.
- [x] 1.2 Move shared shell-owned copy and shared display labels out of
      hardcoded strings and model label getters into the shared translation
      boundary.
- [x] 1.3 Wire desktop and mobile app roots to the shared locale delegates,
      supported locales, and localized app titles.

## 2. Shell locale behavior

- [x] 2.1 Add device-locale defaulting plus shell-local persisted locale
      override for both desktop and mobile shells.
- [x] 2.2 Expose an operator-visible locale switch path in both shells through
      compact shell menu or chrome entry points without making locale a
      host-global setting.
- [x] 2.3 Add locale-aware shell test helpers so widget tests can pin locale and
      assert translated copy deterministically.

## 3. Control-plane metadata localization

- [x] 3.1 Extend provider descriptor, provider-setting, and validation or
      availability display metadata with localized variants plus base-string
      fallback.
- [x] 3.2 Let shells send locale preference when requesting display metadata and
      keep provider ids, field keys, and violation codes locale-neutral.
- [x] 3.3 Update shared provider forms and shell surfaces to render localized
      host metadata when present and fall back cleanly otherwise.

## 4. Verification

- [x] 4.1 Run the smallest relevant Flutter tests for the shared i18n package,
      shared shell core, desktop shell, and mobile shell.
- [x] 4.2 Run `flutter analyze` for `desktop/gui_shell` and `mobile/gui_shell`
      after the i18n wiring lands.
- [x] 4.3 Run strict OpenSpec validation for
      `add-36-flutter-shell-internationalization`.
- [x] 4.4 Manually verify locale switch, fallback, and provider metadata
      rendering on one desktop shell target and one mobile shell target.
