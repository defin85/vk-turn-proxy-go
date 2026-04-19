## Context

The mobile owned-browser continuation contract already keeps provider browser
state inside app-managed `WebView` storage and away from the user's normal
browser profile. That boundary is correct, but the current implementation also
clears that app-owned state whenever the challenge route starts or closes.

That means the product currently gets the worst of both worlds for compatible
embedded flows:

- the app already owns a browser sandbox
- but the operator still has to re-enter login on each new embedded challenge

This change should preserve the sandbox boundary while letting the app reuse
that owned browser state across challenge sessions on the same mobile install.

## Goals / Non-Goals

- Goals:
  - Remember embedded provider sign-in across compatible mobile owned-browser
    challenges on the same app install.
  - Keep remembered state inside the app-owned browser sandbox.
  - Provide one explicit reset path for the operator.
  - Preserve fail-closed continuation semantics when remembered state is not
    sufficient.
- Non-Goals:
  - Do not import cookies, passwords, or profile state from the user's system
    browser.
  - Do not add cloud sync, cross-device sync, or profile export of browser
    session state.
  - Do not redefine desktop challenge handling in this slice.
  - Do not treat remembered sign-in as proof that a provider challenge is
    resolved.

## Decisions

### Decision: Reuse the app-owned browser sandbox instead of recreating it per route

For compatible owned-browser mobile challenges, the shell should reuse the
same app-owned `WebView` cookie and storage sandbox across route lifetimes on
the same install.

That means closing the challenge screen no longer implies clearing embedded
sign-in state. The remembered session remains app-owned and local to the
mobile install.

### Decision: Remembered reuse stays behind explicit compatibility approval

Remembered embedded sign-in must remain an explicit product decision, not an
accidental side effect of opening an owned-browser surface.

That means the shell should enable remembered reuse only for provider flows
that the product explicitly marks as compatible with both owned-browser
continuation and remembered sign-in reuse. The shell must not infer that
policy from provider-name checks or other UI-local heuristics.

If the current control-plane metadata cannot yet express remembered-reuse
approval directly, the implementation should keep one centralized documented
runtime policy until the typed contract grows that field.

### Decision: Keep remembered sign-in separate from ordinary shell persistence

The shell already redacts ordinary persisted shell state. Remembered browser
sign-in should not be copied into profile JSON, preferences, diagnostics, or
other shell-local persistence formats.

The browser sandbox may persist through the platform `WebView` storage layer,
but the shell must continue to treat that as a separate capability boundary,
not as reusable profile data.

### Decision: Reset is explicit and scoped

Because remembered sign-in changes operator expectations, the shell needs one
explicit reset path such as `Forget embedded sign-in`.

That reset should clear only the app-owned browser state used for embedded
continuation:

- cookies
- other `WebView` storage needed for that sign-in session

It must not wipe:

- saved profiles
- selected profile state
- provider drafts
- unrelated shell preferences or diagnostics

### Decision: Continuation still fails closed

Remembered sign-in is a convenience, not a success shortcut.

If the provider still requires fresh auth or if the embedded session cannot
produce the required cookies or completion signals, the mobile shell must stay
on the existing fail-closed path. The change only removes unnecessary fresh
login prompts when the app-owned browser session is still valid.

### Decision: First slice keeps reset scope product-global

The current shipped approval gate for owned-browser mobile continuation is
narrow. The first slice can therefore use one product-global embedded-browser
reset action rather than inventing per-provider browser-profile partitioning.

If multiple owned-browser providers ship later, the product can narrow that
scope in a follow-up change.

## Risks / Trade-offs

- Remembered browser state increases the time window during which an app-owned
  sign-in remains valid on the device.
  Mitigation: keep it inside the app sandbox, provide explicit reset, and do
  not export it through ordinary shell persistence.
- Operators may assume remembered sign-in means challenge completion is always
  automatic.
  Mitigation: keep fail-closed completion semantics and do not relabel
  remembered sign-in as resolved provider state.
- Resetting only cookies may be insufficient if the provider relies on other
  `WebView` storage.
  Mitigation: define reset as clearing the embedded browser session state, not
  only one cookie jar call.

## Migration Plan

1. Stop unconditional clearing of app-owned browser state on challenge route
   start and dispose for remembered-sign-in flows.
2. Add one explicit reset action in the mobile shell.
3. Update owned-browser continuation logic and tests for reuse vs reset.
4. Update docs and validate the change strictly.
