## 1. Windows feasibility and contract alignment
- [ ] 1.1 Choose the first Windows classifier/enforcement approach based on a
      repo-owned spike with packaging and privilege evidence
- [ ] 1.2 Define Windows app inventory fields and identity kinds that map to the
      shared desktop app-routing contract
- [ ] 1.3 Define policy-aware handling for unattributed or unenforceable flows
- [ ] 1.4 Keep `windows_wintun` app routing unavailable until classifier
      prerequisites are satisfied

## 2. Host implementation
- [ ] 2.1 Add Windows host capability reporting for app-routing prerequisites
      and unavailable reasons
- [ ] 2.2 Implement Windows app inventory and selector validation inside the
      packaged Windows host boundary
- [ ] 2.3 Implement the first process-to-flow classifier or equivalent
      enforcement path for selected app traffic
- [ ] 2.4 Ensure partial classifier or filter startup is cleaned up before
      returning failure

## 3. Tests and evidence
- [ ] 3.1 Add host tests proving `windows_wintun` does not imply app routing
      without classifier support
- [ ] 3.2 Add selector validation tests for unknown, stale, and unenforceable
      Windows app identities
- [ ] 3.3 Add a Windows smoke proving one selected app routes through the tunnel
      while a non-selected app is not silently captured
- [ ] 3.4 Add diagnostics evidence that reports classifier, enforcement, and
      cleanup stages separately from Wintun adapter readiness

## 4. Validation
- [ ] 4.1 Run
      `openspec validate add-69-flow-9-windows-app-routing-classifier-host --strict --no-interactive`
