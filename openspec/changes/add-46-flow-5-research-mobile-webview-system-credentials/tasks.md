## 1. Capability Boundary
- [ ] 1.1 Define `mobile-webview-system-credentials` as a separate capability
  from app-owned embedded sign-in memory.
- [ ] 1.2 Clarify that ambient Android autofill or password-manager hints do
  not automatically count as supported system credential integration.

## 2. Integration Design
- [ ] 2.1 Document the Android-first intentional integration path, including
  `Credential Manager`, `WebView`, and relying-party prerequisites.
- [ ] 2.2 Define fail-closed behavior when platform support, trust binding, or
  relying-party web support is missing.
- [ ] 2.3 Define the reset and ownership boundary between app-owned embedded
  browser state and provider-held system credentials.

## 3. Provider Evidence
- [ ] 3.1 Define the evidence required before enabling this path for a real
  provider flow, including web capability proof, native Android proof, and UX
  validation.
- [ ] 3.2 Keep current owned-browser support honest when that evidence is
  missing, partial, or provider-specific.

## 4. Validation
- [ ] 4.1 Run `openspec validate add-46-flow-5-research-mobile-webview-system-credentials --strict --no-interactive`.
