# Provider Matrix

| Provider | Status | Credential source | Notes |
| --- | --- | --- | --- |
| `vk` | runtime implemented | provider adapter + client runtime | Live credential resolution plus single-session UDP/DTLS runtime are implemented; explicit compatibility evidence is tracked separately under `04-add-vk-runtime-compatibility-evidence` |
| `yandex-telemost` | legacy | provider adapter | Legacy path only; do not treat as active product target |
| `generic-turn` | available | static provider link + client runtime | Deterministic provider for CI, harness-backed integration tests, and local first-slice runtime checks with no live signaling |

Open questions:
- whether credentials are stable enough for production support
- whether rebinding resilience must be guaranteed for mobile networks
- which providers are officially in scope for long-term support
