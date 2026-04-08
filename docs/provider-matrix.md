# Provider Matrix

| Provider | Status | Credential source | Notes |
| --- | --- | --- | --- |
| `vk` | runtime implemented | provider adapter + client runtime | Live credential resolution plus the supported one-session transport matrix (`mode=auto|udp|tcp`, pair-specific `ingress=udp|tcp`, `dtls=true|false` for UDP ingress, `dtls=true` for TCP ingress, literal-IP `bind-interface`) are implemented; replayable VK runtime assets under `test/compatibility/vk/runtime/` currently anchor the `ingress=udp` baseline, while `tcp -> tcp` overlay coverage is deterministic in `internal/session`, `internal/tunnelserver`, and `test/turnlab` |
| `yandex-telemost` | legacy | provider adapter | Legacy path only; do not treat as active product target |
| `generic-turn` | available | static provider link + client runtime | Deterministic provider for CI, harness-backed integration tests, and local pair-specific overlay checks (`udp -> udp`, `tcp -> tcp`) with no live signaling |

Open questions:
- whether credentials are stable enough for production support
- whether rebinding resilience must be guaranteed for mobile networks
- which providers are officially in scope for long-term support
