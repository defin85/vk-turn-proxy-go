# Provider Matrix

| Provider | Status | Credential source | Notes |
| --- | --- | --- | --- |
| `vk` | runtime implemented | provider adapter + client runtime | Live credential resolution plus the supported one-session transport matrix (`mode=auto|udp|tcp`, `dtls=true|false`, literal-IP `bind-interface`) are implemented; replayable compatibility evidence lives under `test/compatibility/vk/runtime/` |
| `yandex-telemost` | legacy | provider adapter | Legacy path only; do not treat as active product target |
| `generic-turn` | available | static provider link + client runtime | Deterministic provider for CI, harness-backed integration tests, and local one-session transport-matrix checks with no live signaling |

Open questions:
- whether credentials are stable enough for production support
- whether rebinding resilience must be guaranteed for mobile networks
- which providers are officially in scope for long-term support
