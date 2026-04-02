# Provider Matrix

| Provider | Status | Credential source | Notes |
| --- | --- | --- | --- |
| `vk` | provider-only | provider adapter | Live credential resolution is available; transport parity follows runtime changes |
| `yandex-telemost` | legacy | provider adapter | Legacy path only; do not treat as active product target |
| `generic-turn` | available | static provider link | Deterministic lab and integration provider with no live signaling |

Open questions:
- whether credentials are stable enough for production support
- whether rebinding resilience must be guaranteed for mobile networks
- which providers are officially in scope for long-term support
