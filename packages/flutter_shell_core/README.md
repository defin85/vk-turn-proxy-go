# Flutter Shell Core

`packages/flutter_shell_core` is the shared platform-neutral Flutter shell core
package for `vk-turn-proxy-go`.

The initial scaffold exists to anchor the repository-root Flutter workspace.
Shared leaf modules will move here incrementally as `refactor-22` lands.

The shared visual layer now also lives here:

- the approved cross-shell RelayDock theme source is based on the current
  mobile shell visual language
- platform-neutral semantic tones, badges, banners, and neutral surface
  treatments belong here when both desktop and mobile consume them
- desktop and mobile keep app-local ownership of layout, chrome, and
  platform-specific wrappers
