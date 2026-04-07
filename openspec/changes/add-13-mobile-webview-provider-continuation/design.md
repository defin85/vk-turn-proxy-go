## Context
The repository already established that browser-assisted continuation must use browser-backed state the tool owns or can observe explicitly.
That works well with a controlled desktop browser, but mobile platforms make "owned browser session" a harder product choice.

System-browser handoff is simpler and more policy-friendly, but it limits how much of the continuation flow the app can observe directly.
Embedded WebView moves that control back into the app at the cost of:
- provider compatibility risk
- platform/store-policy review risk
- higher lifecycle and cookie-sandbox complexity

Because those trade-offs are material, WebView should be proposed as a separate architecture branch instead of silently becoming the default mobile handoff model.

## Goals
- Provide a path for full in-app control over eligible mobile provider continuation flows.
- Keep owned session state inside the app sandbox rather than depending on external browser profiles.
- Preserve one typed challenge and session model across shell, host bridge, and runtime.
- Keep unsupported providers on a fail-closed documented path instead of hidden fallback behavior.

## Non-Goals
- Replace the default system-browser mobile handoff for all providers.
- Import cookies or session state from the user's regular browser.
- Hide provider automation inside an invisible WebView.
- Claim that every provider or every platform review policy will accept embedded continuation.

## Decisions
### Decision: Treat WebView continuation as optional and provider-gated

Embedded continuation should only be available when a provider explicitly supports or tolerates it and the product enables that mode for the target platform.

The runtime must not silently move a provider from system browser handoff into WebView mode.

### Decision: Keep owned browser state inside an app-managed sandbox

If the app uses WebView continuation, cookies, storage, and related browser state must stay in app-owned mobile storage for that embedded session.
The implementation must not reach into the user's default browser profile.

### Decision: Surface WebView continuation as an explicit challenge mode

The mobile shell should not infer WebView behavior from provider names.
The host or challenge contract should declare that the challenge must run in an owned in-app web session, and the shell should render that documented mode explicitly.

### Decision: Fail closed when embedded continuation cannot be validated

If the provider flow breaks inside WebView, if required completion signals are missing, or if policy disallows the mode, the system must fail with an explicit challenge or provider-resolution error.
It must not silently claim success or downgrade into an undefined continuation path.

### Decision: Keep the default mobile path system-browser-oriented

This change adds an optional higher-control branch.
It does not replace the recommended system-browser handoff path defined by the mobile shell baseline and browser-return/auto-resume follow-up work.

## Alternatives Considered
### Only improve system-browser return handling

Rejected as the sole answer.
That improves UX, but it does not solve the full-control/session-ownership problem for providers that bind continuation tightly to one browser context.

### Move every provider to WebView by default

Rejected.
This is too risky for provider compatibility, accessibility, testing, and store-policy review.

### Reuse the user's installed browser profile inside the app

Rejected.
It conflicts with the repository's existing controlled-browser and secret-handling stance.

## Risks / Trade-offs
- Some providers may block or degrade inside embedded WebView.
  Mitigation: provider-gated opt-in and fail-closed fallback to documented non-WebView behavior.
- Android and iOS WebView implementations diverge operationally.
  Mitigation: keep the shared contract typed and push platform specifics into thin bridges.
- Accessibility, autofill, password managers, and cookie persistence can behave differently than in the system browser.
  Mitigation: treat this as a dedicated capability with explicit validation instead of an invisible implementation detail.
- App-store or platform review rules may constrain some forms of embedded web authentication.
  Mitigation: make WebView continuation optional and policy-aware rather than baseline.

## Migration Plan
1. Define the typed owned-WebView challenge mode and provider policy gate.
2. Define mobile shell selection logic between system-browser and owned-WebView challenge surfaces.
3. Define app-owned session storage and lifecycle expectations for embedded continuation.
4. Add provider-scoped validation before any implementation claims general support.
