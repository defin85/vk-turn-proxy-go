# Verification

Date: 2026-04-18

Control-plane precondition:
- `go run ./cmd/clientd -listen 127.0.0.1:7777`

## Desktop shell

Target:
- Linux desktop target from `desktop/gui_shell`
- Launch entrypoint: `test_driver/driver_main.dart`

Manual checks:
1. Started with the shell already restored in `ru`.
2. Confirmed the ready summary rendered `Локальный хост готов` with detail `127.0.0.1:7777`.
3. Switched locale through the shell locale menu from `ru` to `en`.
4. Confirmed shell chrome and ready-state copy changed to `Diagnostics`, `Live work`, `Reconnect`, `Refresh`, `Local host ready`, and `Contract 1`.
5. Confirmed the compact host detail stayed normalized to `127.0.0.1:7777` instead of keeping a stale localized prefix.
6. Confirmed provider metadata fallback still rendered in the localized shell: the profile workspace kept the provider family value `Generic TURN` while surrounding shell labels switched languages.
7. Switched back from `en` to `ru` and confirmed `Локальный хост готов`, `Диагностика`, `Текущая работа`, `Переподключить`, `Обновить`, and `Контракт 1` returned without stale English shell-owned status text.

Desktop result:
- PASS

## Mobile shell

Target:
- Android 11 device `21051182G`
- Launch entrypoint: `mobile/gui_shell/test_driver/driver_main.dart`

Manual checks:
1. Started in `en` and opened the host-status sheet from the header indicator.
2. Confirmed the ready-state title and message rendered `Mobile host ready` and `Connected to mobile host bridge http://127.0.0.1:46633`.
3. Switched locale from `en` to `ru`.
4. Confirmed home chrome changed to `Главная`, `Профили`, `Провайдеры`, `Маршрутизация`, `Поддержка`, and the home copy changed to Russian.
5. Re-opened the host-status sheet and confirmed it re-localized to `Мобильный хост готов` and `Подключено к мосту мобильного хоста http://127.0.0.1:46633` without leaving stale English shell-owned copy.
6. Opened the `Providers` surface and confirmed provider metadata rendered in Russian while keeping locale-neutral fallback values:
   `Type: VK Calls` -> `Тип: VK Calls`
   `Used in Profiles` -> `Используется в Профилях`
   `Available` -> `Доступно`
   Base provider family value `VK Calls` remained unchanged as expected.
7. Switched back from `ru` to `en` and confirmed the same host-status sheet returned to `Mobile host ready` / `Connected to mobile host bridge http://127.0.0.1:46633`.

Mobile result:
- PASS

## Conclusion

- Locale switching is operator-visible and shell-local on both targets.
- Shell-owned ready-status copy re-localizes immediately on both targets.
- Localized metadata labels render when available and locale-neutral fallback values remain stable.
