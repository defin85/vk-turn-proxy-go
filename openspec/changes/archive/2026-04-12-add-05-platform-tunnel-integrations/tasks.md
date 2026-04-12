## 1. Platform tunnel contract
- [x] 1.1 Define the mode-specific control-plane capability model for system tunnel support across desktop and mobile platforms
- [x] 1.2 Define explicit startup stages and failure semantics for permissions, entitlements, drivers, route preparation, and runtime attach

## 2. Host integration model
- [x] 2.1 Define platform-host responsibilities for Android, iOS/macOS, Windows, and Linux tunnel integration, including which prerequisites each host owns
- [x] 2.2 Define the neutral host-to-runtime traffic handoff without mixing OS-specific logic into provider code
- [x] 2.3 Define how shells consume host capability and startup-stage reports without inferring support from platform heuristics

## 3. Verification
- [x] 3.1 Define per-platform smoke and fail-closed validation expectations, including capability-report and startup-stage evidence
- [x] 3.2 Run `openspec validate add-05-platform-tunnel-integrations --strict --no-interactive`
