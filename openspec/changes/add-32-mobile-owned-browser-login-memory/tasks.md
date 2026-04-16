## 1. Remembered app-owned browser session contract
- [ ] 1.1 Define the mobile owned-browser session lifetime so compatible
      embedded challenges can reuse app-owned cookies and browser storage on
      the same install instead of clearing them on every route open/close.
- [ ] 1.2 Define one explicit reset path for remembered embedded sign-in that
      clears app-owned browser session state without wiping saved profiles,
      provider drafts, or unrelated shell preferences.
- [ ] 1.3 Add mobile tests for remembered sign-in reuse, explicit reset, and
      fail-closed behavior when the remembered browser state is missing or no
      longer valid for continuation.

## 2. Mobile shell UX and wiring
- [ ] 2.1 Update the owned-browser mobile flow to stop unconditional cookie
      clearing for remembered-sign-in paths while preserving the documented
      app-owned sandbox boundary.
- [ ] 2.2 Expose an operator-visible `Forget embedded sign-in` or equivalent
      reset action from the mobile shell.
- [ ] 2.3 Keep continuation fail-closed when the provider still requires fresh
      auth, the required cookie domains remain empty, or the embedded session
      cannot prove completion.

## 3. Validation
- [ ] 3.1 Update mobile shell docs to describe remembered embedded sign-in,
      its reset path, and its sandbox boundary.
- [ ] 3.2 Run the smallest relevant mobile analyze and test checks for the
      owned-browser path.
- [ ] 3.3 Run `openspec validate add-32-mobile-owned-browser-login-memory
      --strict --no-interactive`.
