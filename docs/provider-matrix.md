# Provider Matrix

| Provider | Status | Credential source | Notes |
| --- | --- | --- | --- |
| `vk` | runtime implemented | provider adapter + client runtime | Live credential resolution plus the supported one-session transport matrix (`mode=auto|udp|tcp`, pair-specific `ingress=udp|tcp`, `dtls=true|false` for UDP ingress, `dtls=true` for TCP ingress, literal-IP `bind-interface`) are implemented; approved mobile owned-browser surfaces now support both the legacy `vk.com/call/join/...` invite flow and the authenticated `https://calls.vk.com/` root-start hosted-call contour, while replayable VK runtime assets under `test/compatibility/vk/runtime/` currently anchor the `ingress=udp` baseline and `tcp -> tcp` overlay coverage remains deterministic in `internal/session`, `internal/tunnelserver`, and `test/turnlab` |
| `yandex-telemost` | legacy | provider adapter | Legacy path only; do not treat as active product target |
| `generic-turn` | available | static provider link + client runtime | Deterministic provider for CI, harness-backed integration tests, and local pair-specific overlay checks (`udp -> udp`, `tcp -> tcp`) with no live signaling |
| `wb-stream` | runtime overlay implemented, planned rollout | `https://stream.wb.ru/` room link | Flow-6 candidate only. The host and probe registry can validate narrow stream.wb.ru room URL shapes and resolve them to a `conference_room` artifact with shell-external `open_room`; it still is not in the ordinary shipped provider catalog and does not imply `generic_turn`, local media execution, embedded browser, account automation, or recording/chat/token export |
| `smarthome` | planned, not shipped | none yet | Flow-6 candidate only. Keep it out of the ordinary supported-provider catalog until the same rollout gate has provider contract, artifact action surface, host/shell readiness, and verification evidence |

## Supported-provider rollout gate

The shipped app-owned provider catalog is intentionally smaller than the set of
provider names that may appear in research artifacts, planned OpenSpec changes,
host descriptors, or local fixtures. Today the ordinary operator-facing shipped
catalog contains only `vk` and `generic-turn`.

`wb-stream` and `smarthome` may be recorded as `planned` or `pending rollout`,
and a host may advertise a runtime overlay descriptor before the app catalog
ships it. That state is not support. A future provider family becomes shipped
only after the committed rollout gate has all of these:

- provider-specific contract
- matching artifact-family action surface
- host readiness
- desktop shell readiness
- mobile shell readiness
- verification evidence

Host-reported provider descriptors are runtime overlays for the current host.
They do not by themselves promote a provider family into the shipped catalog.
Presets, templates, disabled bootstrap assets, and archived research follow the
same rule: they are non-authoritative unless the rollout gate is satisfied.

For `wb-stream`, the committed runtime overlay currently accepts only
fixture-backed `https://stream.wb.ru/{room|rooms|meeting|meetings|join}/{id}`
links. Query strings, fragments, userinfo, explicit ports, alternate hosts, and
unsupported path shapes fail closed at the provider stage. The provider does not
fetch pages or attempt WBAAS anti-bot bypass.

## Conference-room action surface

The host contract exposes a provider-neutral `conference-room-actions`
capability for resolved `conference_room` artifacts. Its first committed action
is `open_room`: shells use the typed `summary.conference_room.room_url`
navigation target and execute it as a shell-external browser handoff.

This action surface is not a provider rollout by itself. It does not promote
`wb-stream`, does not create a same-device conference executor, and does not
reinterpret conference-room artifacts as `generic_turn` exports or tunnel
startup inputs.

Open questions:
- whether credentials are stable enough for production support
- whether rebinding resilience must be guaranteed for mobile networks
- which planned providers are officially in scope for long-term support after
  the rollout gate is satisfied
