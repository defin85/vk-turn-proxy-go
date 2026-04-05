## Context

Desktop is the least constrained place to ship the first GUI because:

- we already have CLI binaries
- sidecar hosting is straightforward
- browser challenge handoff is easier than on mobile
- diagnostics and packaging are easier to iterate on

The desktop GUI should not become a second runtime implementation.
It should remain a shell over the client control plane.

## Goals

- Deliver one desktop UX for Windows, macOS, and Linux
- Manage the runtime through the local control plane
- Supervise a compatible local sidecar host automatically
- Support browser challenge handoff, diagnostics export, and session status without terminal use

## Non-Goals

- Mobile UX
- System tunnel integration in this change
- Native transport overlay support beyond what the host/runtime already supports

## Decisions

### Decision: Use one cross-platform desktop shell

The desktop client should share one UI codebase across Windows, macOS, and Linux.
Platform-specific code belongs only in thin host integrations such as tray, file-system paths, autostart, and local IPC bootstrapping.

### Decision: Implement the desktop shell in Flutter

The desktop GUI shell uses Flutter as the canonical UI stack.
That keeps the desktop shell aligned with the planned mobile shell, preserves one widget/application model across platforms, and avoids introducing a separate webview or Rust-host UI stack just for desktop.

### Decision: Treat the runtime as a local sidecar

The desktop GUI starts, upgrades, and supervises a compatible local host process rather than embedding the runtime in the UI process.

### Decision: Use system browser handoff for provider challenges

Desktop challenge handling should prefer system browser or explicit helper handoff instead of embedding fragile provider flows inside the UI shell.

## Risks / Trade-offs

- Desktop packaging and sidecar upgrade logic can drift across OSes
- Browser challenge handoff needs careful state continuity between GUI and host
- GUI and sidecar version skew must be handled explicitly

## Validation Plan

- UI integration tests against a mocked control plane
- End-to-end desktop smoke flow against a real local host
- Packaging checks for Windows, macOS, and Linux
- `openspec validate add-02-desktop-gui-shell --strict --no-interactive`
