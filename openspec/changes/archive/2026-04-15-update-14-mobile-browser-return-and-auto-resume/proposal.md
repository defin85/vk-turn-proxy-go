# Change: [14] Update mobile browser return and auto-resume

## Why
The current challenge model keeps browser continuation host-driven and explicit, but the live desktop UX already exposed a friction point: after the operator completes captcha or `Join` in the browser, the shell still needs a second explicit confirmation before the host continues.

That manual second step is tolerable on desktop, but it becomes clumsy on mobile because Android and iOS can detect app return, deep-link callbacks, and foreground resume events.
At the same time, those signals do not prove that the provider challenge actually succeeded.

The mobile contract needs one safe middle ground:
- use platform-native browser return signals when available
- attempt one best-effort automatic continue on supported return paths
- keep an explicit manual fallback when return is ambiguous or insufficient

## Sequence
- Order: `14`
- Depends on: `add-03-mobile-gui-shell`
- Unblocks: `add-05-platform-tunnel-integrations`

## What Changes
- Extend the mobile challenge contract with machine-readable browser-return metadata and completion modes instead of treating every challenge as pure manual confirmation.
- Define platform-native browser return handling for Android and iOS as handoff inputs, not as implicit proof that provider resolution succeeded.
- Let the mobile shell issue one best-effort automatic challenge continue when an eligible challenge returns through an associated app link, universal link, or documented foreground-resume path.
- Require a clear post-browser manual fallback action when automatic continue is unavailable, ambiguous, or does not resolve the challenge.
- Clarify UI semantics so the post-browser confirmation action is distinct from the action that opens the browser handoff itself.

## Impact
- Affected specs: `mobile-gui-client`, `client-control-plane`
- Affected code: future mobile Flutter shell, mobile host bridge, typed challenge metadata, native deep-link/lifecycle glue, mobile/browser handoff docs, shared challenge copy
