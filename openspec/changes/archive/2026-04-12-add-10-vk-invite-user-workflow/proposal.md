# Change: [10] Add canonical VK invite user workflow

## Why
The repository now has a working VK-backed runtime path, browser-mediated continuation, and a desktop/control-plane surface, but it still lacks a product-level contract for how real users are supposed to use that stack.

Without that contract, documentation and UI decisions can drift between operator-only transport knobs and the actual user-facing workflow: who creates the call, how invite links are exchanged, what the end user has to enter, and when a session is truly ready instead of still sitting at preview.

## What Changes
- Add a canonical user workflow for VK-backed sessions based on ordinary `vk.com/call/join/...` invite links created outside the product.
- Define the supported role split: organizer or dispatcher creates the VK call, invite sharing stays out-of-band, and the end user consumes the invite inside the product.
- Define that the standard user flow is invite-first and operator-managed, so peer and transport defaults are not required end-user inputs.
- Define the explicit browser continuation and `Join` boundary that must be crossed before the product may report `ready`.
- Keep advanced transport and support surfaces available without redefining them as the normal end-user path.

## Impact
- Affected specs: `vk-invite-user-workflow` (new)
- Affected code: `desktop/gui_shell`, `pkg/clientcontrol`, `cmd/clientd`, `internal/session`, `README.md`, `desktop/gui_shell/README.md`
