## 1. Platform tunnel contract
- [ ] 1.1 Define the capability model for system tunnel support across desktop and mobile platforms
- [ ] 1.2 Define explicit startup and failure semantics for permissions, entitlements, drivers, and route preparation

## 2. Host integration model
- [ ] 2.1 Define platform-host responsibilities for Android, iOS/macOS, Windows, and Linux tunnel integration
- [ ] 2.2 Define how platform tunnel hosts hand traffic to the client runtime without mixing OS-specific logic into provider code

## 3. Verification
- [ ] 3.1 Define per-platform smoke and fail-closed validation expectations
- [ ] 3.2 Run `openspec validate add-05-platform-tunnel-integrations --strict --no-interactive`
