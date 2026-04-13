## Context
The repository already decided that browser-assisted provider continuation must stay host-driven and fail closed when browser-backed state is unavailable.
That decision remains correct.

However, the current UX contract still assumes that the shell only knows two states:
- open browser handoff
- wait for the operator to confirm completion explicitly

Mobile platforms offer more signals than that:
- Android can bring the app back through App Links or normal foreground resume after a browser handoff
- iOS can return through Universal Links or an authentication-session callback path when the flow supports it
- both platforms can notify the app that it became foreground again after the browser step

Those signals are useful, but they are weaker than "provider continuation completed successfully".
The mobile contract should use them to reduce friction without overclaiming readiness.

## Goals
- Reduce the double-confirmation friction for browser-mediated mobile challenge flows.
- Keep provider continuation fail-closed and host-driven.
- Reuse one typed challenge model across desktop and future mobile shells.
- Let mobile shells distinguish "open browser", "resume after browser", and "manual post-browser confirmation" without parsing provider text.

## Non-Goals
- Claim that foreground return alone proves challenge completion.
- Replace controlled-browser or browser-observed flows with hidden heuristics.
- Introduce provider-specific browser UI in the shared Flutter shell.
- Make desktop challenge flows depend on mobile-only platform callbacks.

## Decisions
### Decision: Add explicit challenge completion modes to the control-plane challenge shape

The control plane should expose machine-readable challenge completion metadata so shells can render the right UX per challenge.

At minimum, the challenge shape should distinguish:
- `manual_confirm`: the shell must wait for an explicit user confirmation after the browser step
- `app_return_callback`: the shell may auto-continue once after a documented app return signal
- `owned_browser_observed`: the host owns the browser session and can observe the continuation state directly

Optional metadata may include:
- whether one automatic continue attempt is allowed for the current challenge
- the supported browser-return signal kinds for that challenge, such as `app_link`, `universal_link`, or `foreground_resume`
- whether a specific deep-link or universal-link return URI is expected
- whether the fallback manual action should remain visible after auto-resume

### Decision: Treat browser return as a continuation hint, not as proof of success

App return signals must be interpreted as "the user may be ready for continuation", not as "the provider challenge definitely succeeded".

The shell may trigger one automatic continue attempt when:
- the challenge advertises an app-return-compatible mode
- the challenge metadata reports the matching return-signal kind for that session
- the app receives that documented return signal while the same challenge is still active

If the host remains in `challenge_required` or fails at `provider_resolve`, the shell must keep or restore explicit manual completion controls.

### Decision: Keep one-shot auto-resume best-effort

Automatic continue should be limited to one attempt per eligible return event sequence.
The shell must not loop on repeated foreground transitions, duplicate callbacks, or bounce between browser and app indefinitely.
The simplest safe guard is to key the auto-resume allowance to the active challenge identifier and clear that allowance only when the host emits a new eligible challenge or leaves the challenge state.

That keeps mobile UX responsive while avoiding false repeated continuations triggered by lifecycle noise.

### Decision: Separate browser-launch actions from post-browser confirmation actions

Current copy such as `Continue in browser` is ambiguous once the browser is already open or the operator has already finished the browser step.

The shell should distinguish at least two UX intents:
- launch or re-open the browser handoff
- confirm that the browser step is complete and the host should continue

Mobile auto-resume reduces the frequency of the second action but does not eliminate the need for it as a fallback.

### Decision: Keep platform-native return plumbing outside provider logic

Provider-specific continuation rules stay inside provider/runtime code.
Platform callbacks, app lifecycle observation, and deep-link registration stay in thin mobile bridge code.

The shared shell consumes typed challenge metadata and typed session events; it does not infer provider success from raw browser URLs.

## Alternatives Considered
### Always auto-continue on foreground resume

Rejected.
Returning to the app does not prove that captcha or `Join` actually completed.

### Keep purely manual post-browser confirmation

Rejected.
It is safe but unnecessarily clumsy on mobile and leaves useful platform signals unused.

### Solve this only with WebView ownership

Rejected for this change.
That is a separate architecture branch with different provider, policy, and lifecycle trade-offs.

## Risks / Trade-offs
- Foreground resume can be noisy, especially when users switch apps without finishing the challenge.
  Mitigation: one-shot auto-resume plus explicit fallback controls.
- Deep-link or universal-link return paths may exist only for some providers or some browser flows.
  Mitigation: keep `manual_confirm` as the baseline mode.
- The control-plane challenge model becomes richer.
  Mitigation: keep metadata small, typed, and provider-agnostic.

## Migration Plan
1. Extend the challenge contract with completion-mode metadata.
2. Define mobile bridge hooks for app return signals and foreground resume.
3. Let the mobile shell attempt one automatic continue when a challenge advertises app-return compatibility.
4. Keep manual confirmation copy and controls for unsupported or ambiguous flows.
5. Update docs and tests so mobile challenge behavior is explicit rather than inferred.
