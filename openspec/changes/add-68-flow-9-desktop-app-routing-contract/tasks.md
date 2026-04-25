## 1. Contract design
- [ ] 1.1 Define the shared desktop application identity shape, including a
      host-owned stable identity key and platform-specific metadata boundaries
- [ ] 1.2 Define desktop app-routing policies separately from Android package
      routing policies
- [ ] 1.3 Extend host capability metadata so app-routing support is scoped to a
      concrete platform-tunnel mode and enforcement layer
- [ ] 1.4 Define fail-closed behavior for hosts that can route by IP but cannot
      classify or enforce app identity

## 2. Control-plane contract
- [ ] 2.1 Add typed desktop app inventory and selector request/response shapes
      to the versioned local control-plane contract
- [ ] 2.2 Add startup validation errors for unsupported desktop app-routing
      policies, unknown app identities, and unenforceable identity kinds
- [ ] 2.3 Preserve existing Android package-routing request semantics without
      reinterpreting package lists as desktop app selectors

## 3. Evidence
- [ ] 3.1 Add contract tests proving desktop hosts do not receive Android
      package-routing fields for desktop app routing
- [ ] 3.2 Add fail-closed tests for desktop tunnel modes that support Wintun or
      another adapter but do not advertise app-routing enforcement
- [ ] 3.3 Add compatibility notes for old hosts that lack desktop app-routing
      capability metadata

## 4. Validation
- [ ] 4.1 Run
      `openspec validate add-68-flow-9-desktop-app-routing-contract --strict --no-interactive`
