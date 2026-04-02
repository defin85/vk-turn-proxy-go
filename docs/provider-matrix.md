# Provider Matrix

| Provider | Status | Credential source | Notes |
| --- | --- | --- | --- |
| `vk` | planned | provider adapter | Primary target for compatibility port |
| `yandex-telemost` | legacy | provider adapter | Legacy path only; do not treat as active product target |
| `generic-turn` | planned | static config | Useful for lab and integration tests |

Open questions:
- whether credentials are stable enough for production support
- whether rebinding resilience must be guaranteed for mobile networks
- which providers are officially in scope for long-term support

