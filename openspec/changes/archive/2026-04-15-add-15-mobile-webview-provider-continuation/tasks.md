## 1. Contract
- [x] 1.1 Define the typed challenge mode and policy gate for optional owned-WebView continuation on mobile
- [x] 1.2 Define how the mobile shell distinguishes system-browser and owned-WebView challenge surfaces through shared metadata

## 2. Platform Behavior
- [x] 2.1 Define Android WebView and iOS WKWebView ownership, lifecycle, and session-storage expectations for provider continuation
- [x] 2.2 Define fail-closed behavior when embedded continuation is unsupported, blocked, or cannot be validated
- [x] 2.3 Define provider-approval criteria before the product can claim WebView continuation support

## 3. Verification
- [x] 3.1 Add contract and integration coverage for owned-WebView challenge selection and failure handling
- [x] 3.2 Run `openspec validate add-15-mobile-webview-provider-continuation --strict --no-interactive`
