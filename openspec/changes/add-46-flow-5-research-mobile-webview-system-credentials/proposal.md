# Change: [46] Define intentional system credential integration for mobile owned WebView

## Why
The archived `add-32-mobile-owned-browser-login-memory` change only covers
app-owned remembered sign-in inside the mobile `WebView` sandbox. That is not
the same thing as intentional integration with Android system credential
providers.

Android now documents an explicit `Credential Manager + WebView` path, but that
path has different prerequisites and trust boundaries than our current
app-owned cookie/storage reuse. The product needs a separate proposal so we do
not accidentally treat ambient autofill or password-manager hints as if they
were a reviewed first-class contract.

## Sequence
- Order: `46`
- Depends on: shipped mobile owned-browser continuation and app-owned embedded
  sign-in memory
- Unblocks: explicit investigation and future implementation of Android system
  credential integration inside approved owned-browser flows

## What Changes
- Define an optional Android-first capability for intentional system credential
  integration inside approved mobile owned-browser `WebView` flows.
- Keep ambient autofill or password-manager suggestions non-contractual unless
  the product explicitly enables the documented system credential path for that
  flow.
- Document the prerequisite boundary for explicit support, including Android
  `Credential Manager` or `WebView` feature support, app-to-site trust binding,
  and relying-party web support.
- Keep app-owned embedded sign-in reset and provider-held system credentials as
  separate boundaries so the shell does not pretend one reset clears the other.

## Impact
- Affected specs: `mobile-webview-provider-continuation`,
  `mobile-webview-system-credentials`
- Affected code: future Android owned-browser bridge wiring,
  `mobile/gui_shell` owned-browser UX and policy gates, related docs and tests
