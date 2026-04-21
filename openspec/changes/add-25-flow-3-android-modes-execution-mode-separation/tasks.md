## 1. Android mode separation contract
- [ ] 1.1 Add the new `android-runtime-mode-separation` capability spec for honest Android system-tunnel versus future non-system modes
- [ ] 1.2 Extend runtime execution planning so `android_vpn_service` cannot be repackaged as a generic stealth or proxy-only mode
- [ ] 1.3 Extend mobile GUI requirements so future Android modes remain separate in operator-facing UX

## 2. Threat-model and future-mode gates
- [ ] 2.1 Define the threat-model and evidence bar required before any future Android mode may claim a different detection surface than `android_vpn_service`
- [ ] 2.2 Define the operator-facing distinction between system-tunnel scope and future non-system app-opt-in relay scope

## 3. Validation
- [ ] 3.1 Run `openspec validate add-25-flow-3-android-modes-execution-mode-separation --strict --no-interactive`
