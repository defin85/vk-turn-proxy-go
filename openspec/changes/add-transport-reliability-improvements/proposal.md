# Change: Add transport reliability improvements

## Why
Live transport quality still depends on long-lived TURN allocations staying healthy across NAT churn, mobile-network behavior, and permission refresh cycles.
Recent source analysis of related implementations suggests there is room to improve our TURN client plumbing without changing provider boundaries or pulling in any captcha/anti-bot behavior.

## What Changes
- Add transport-side reliability improvements around TURN socket creation and long-lived allocation handling for the supported client runtime matrix.
- Expand deterministic lab coverage so long-lived allocation and permission-refresh behavior can be exercised locally.
- Keep the scope limited to provider-agnostic transport/runtime reliability; exclude captcha solving, hidden provider fallbacks, and unrelated Android UI behavior.

## Impact
- Affected specs: `tunnel-client-runtime`, `turn-lab-harness`
- Affected code: `internal/transport`, `internal/session`, `test/turnlab`, runtime integration tests, docs
