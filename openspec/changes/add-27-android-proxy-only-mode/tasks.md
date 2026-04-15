## 1. Proxy-only mode specification
- [ ] 1.1 Add the new `android-proxy-only-mode` capability spec for the first concrete non-system Android runtime workflow
- [ ] 1.2 Extend `android-runtime-mode-separation` and `runtime-execution-planning` so proxy-only mode has its own documented execution tuple and does not inherit `android_vpn_service` semantics
- [ ] 1.3 Extend `mobile-gui-client` and `client-control-plane` so the shell can render typed proxy-only scope, endpoint metadata, and ready/failure state

## 2. Delivery model
- [ ] 2.1 Define the packaged ownership split for proxy-only mode across Flutter UI, the embedded Go host, and any thin Android-native platform adapter
- [ ] 2.2 Define the explicit app-opt-in/operator-opt-in workflow and the rule that proxy-only mode does not imply transparent device-wide capture

## 3. Validation
- [ ] 3.1 Run `openspec validate add-27-android-proxy-only-mode --strict --no-interactive`
