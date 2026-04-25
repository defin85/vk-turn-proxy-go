## Context

The repository already has:

- a desktop-specific shell contract built around a compact left pad, one
  dominant canvas, and an optional inspector;
- a mobile-specific product contract built around workflow-first destinations;
- a shared shell core that already owns visual primitives and other
  platform-neutral models.

The current problem is not visual drift alone. The desktop `Home` workbench is
still composed as a desktop-local overview with duplicated quick actions and
multiple equal-weight cards, while the mobile `Home` body already has a
clearer product hierarchy.

## Goals / Non-Goals

- Goals:
  - reuse one product-facing `Home` body across desktop and mobile;
  - reduce desktop `Home` noise without weakening desktop shell affordances;
  - keep the shared extraction narrow enough to validate quickly.
- Non-Goals:
  - merge desktop and mobile into one app;
  - move desktop host supervision or mobile host bridge ownership into shared
    code;
  - refactor `Profiles`, `Providers`, `Routing`, or `Support` in the same
    change.

## Decisions

- Decision: extract only the `Home` body in this change.
  - Why: it is the smallest slice that can prove the architecture and improve
    desktop hierarchy immediately.
  - Alternatives considered:
    - extract all workflow surfaces now: rejected as too large and risky for
      one step.
    - keep duplicating mobile and desktop `Home`: rejected because desktop
      noise already shows drift in ownership and hierarchy.

- Decision: keep desktop shell routing, navigation, and inspectors app-local.
  - Why: they depend on desktop-specific command surfaces, keyboard behavior,
    and width adaptation.
  - Alternatives considered:
    - move `DesktopCanvasRoute` and inspector behavior into shared core:
      rejected because that would violate the platform-neutral boundary.

- Decision: shared `Home` should be body-level only.
  - Why: the same body must fit mobile navigation and desktop canvas embedding.
  - Alternatives considered:
    - share the full page scaffold including rail, bar, and inspector entry:
      rejected because those belong to platform shell chrome.

## Risks / Trade-offs

- Desktop could become too phone-like if the extracted body does not expose
  enough density hooks or width-aware layout.
- Shared `Home` could turn into an oversized parameter object if desktop and
  mobile callbacks are not kept focused on user intent.
- If desktop quick actions are removed too aggressively, support affordances
  could become harder to discover.

## Migration Plan

1. Introduce a shared `Home` surface and supporting frame helpers in
   `flutter_shell_core`.
2. Reconnect the mobile `Home` route to that shared surface without changing
   destination structure.
3. Replace the desktop `Home` workbench body with the shared surface inside the
   current canvas route.
4. Trim desktop-only duplicated `Home` chrome and update tests.

## Open Questions

- Whether desktop will still need one small shell-local readiness wrapper above
  the shared `Home` body when host state is ready but platform tunnel
  capabilities are relevant.
- Whether the shared `Home` body should own support action labels or receive
  them entirely from app-local copy wrappers.
