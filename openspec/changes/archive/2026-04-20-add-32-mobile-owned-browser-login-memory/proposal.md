# Change: [32] Remember app-owned sign-in across mobile owned-browser challenges

## Why
The current mobile owned-browser flow deliberately clears embedded `WebView`
cookies on entry and on exit. That is fail-closed, but it also forces the
operator to log in again every time a compatible provider challenge reopens in
the embedded browser.

For the currently shipped mobile owned-browser flow, that repeated sign-in is
unnecessary friction. The product needs one explicit remembered-sign-in path
that stays inside the app sandbox instead of treating every owned-browser
challenge as a fresh browser profile.

## Sequence
- Order: `32`
- Depends on: `add-29-mobile-vpn-product-shell`
- Unblocks: repeated mobile owned-browser challenge continuation without
  forced re-login on the same app install

## What Changes
- Let compatible mobile owned-browser continuations reuse app-owned embedded
  browser cookies and storage across challenge sessions on the same install.
- Keep remembered sign-in inside app-managed `WebView` storage and separate
  from the user's external browser profile and ordinary shell persistence.
- Require one explicit mobile action to forget or reset remembered embedded
  sign-in without wiping saved profiles or other shell state.
- Keep owned-browser continuation fail-closed when required cookies are
  missing, invalid, or no longer satisfy the provider challenge.

## Impact
- Affected specs: `mobile-webview-provider-continuation`, `mobile-gui-client`
- Affected code: `mobile/gui_shell` owned-browser challenge session handling,
  mobile support or challenge UX for reset, related docs, and mobile tests
