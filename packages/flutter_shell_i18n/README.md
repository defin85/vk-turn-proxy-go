# flutter_shell_i18n

Shared shell localization package for `vk-turn-proxy-go`.

This package owns the repository-shared translation source for:

- `desktop/gui_shell`
- `mobile/gui_shell`
- `packages/flutter_shell_core`

## Generation

Run the repo-owned generation step from the repository root:

```bash
./scripts/generate-flutter-shell-i18n.sh
```

That command runs `dart run slang` inside this package and commits generated
source back into `lib/src/i18n/`.
