## Context

The repository already has a desktop shell and a partially improved workspace
shape, but the current UI still shows transitional design debt:

- profile and provider workflows still dominate the shell structure
- activity and diagnostics remain too tightly coupled to the main workflow
- the shell still reads more like a migration dashboard than a mature desktop
  VPN workbench

The reviewed desktop references show a more stable pattern:

- v2rayN uses a dense workbench with toolbar, profile table, and a lower status
  surface
- NekoRay uses top controls plus a main profile table and a lower tab strip for
  logs, connections, and traffic graphs
- Clash Verge Rev uses a persistent navigation shell with dedicated pages for
  home, proxies, profiles, connections, rules, logs, and settings
- Hiddify remains more consumer-friendly, but still uses explicit desktop
  navigation and a separate sidebar stats surface instead of stretching the
  phone workflow
- OpenVPN Connect represents the opposite extreme: a minimal desktop client
  centered on importing a profile and toggling one connection, with much less
  emphasis on workbench-style profile, routing, and support surfaces

## Goals / Non-Goals

- Goals:
  - Make the desktop shell feel like a real VPN workbench.
  - Keep one dominant task canvas at a time.
  - Separate overview, profile management, routing, activity, diagnostics, and
    settings into explicit desktop destinations.
  - Keep live runtime status visible without letting logs or diagnostics steal
    the main work area by default.
- Non-Goals:
  - Do not redesign mobile UI in this change.
  - Do not change runtime or platform-tunnel semantics.
  - Do not remove support-oriented surfaces such as diagnostics or logs.
  - Do not force every desktop width into the same exact pane count.

## Decisions

### Decision: Desktop shell becomes a workbench, not a stretched dashboard

The shell uses one stable navigation region plus one dominant canvas route.

This route can be:

- overview/home
- profiles
- routing
- activity
- diagnostics
- settings

The shell does not place multiple peer canvases with equal emphasis side by
side as the default operating mode.

### Decision: Home is concise and operational

Desktop home becomes a short overview and command surface:

- current mode or tunnel summary
- selected profile or active route summary
- quick entry points into the real work surfaces
- compact live status

It is not the place for full profile editing, giant diagnostics payloads, or
raw event browsing.

OpenVPN Connect is useful here as a reminder that desktop home can stay simple,
but this repository still needs a richer workbench around that home because the
desktop product owns more than a single imported profile plus connect toggle.

### Decision: Profiles and routing become dense desktop work surfaces

Profiles and routing each get dedicated desktop-first surfaces with denser
composition such as list/detail, workbench panels, or focused editors.

This follows v2rayN, NekoRay, and Clash Verge Rev more than OpenVPN Connect or
the most consumer-simple part of Hiddify. Desktop users should not have to
work through stretched card stacks to manage profiles and routing.

### Decision: Live runtime detail moves to a bottom ribbon or explicit support pane

Logs, live connections, and similar runtime detail belong in:

- a bottom ribbon
- an expandable lower panel
- or a clearly secondary support pane

They remain quickly reachable, but they do not claim the main task canvas by
default.

### Decision: Persistent left navigation stays primary

Desktop widths should prefer a stable left navigation surface rather than a
mobile-style bottom bar or one-off drawer.

Narrower desktop widths may collapse that navigation, but the logical
destination set remains the same.

## Risks / Trade-offs

- A denser workbench can feel heavier than the current shell for first-time
  users.
  Mitigation: keep home concise and use it as the lightweight landing surface.
- Moving logs and activity out of the main canvas can hide important failure
  information if the status surface is weak.
  Mitigation: preserve compact live status and one-step entry into support
  surfaces.
- Overfitting to desktop references can create a shell that feels unlike the
  rest of the repo.
  Mitigation: keep the repo's typed control-plane semantics and workflow logic,
  but change the information architecture.

## Migration Plan

1. Refine the destination model and shell navigation.
2. Reduce home to an overview plus entry points.
3. Move profile and routing work into dedicated desktop surfaces.
4. Introduce or strengthen a lower live-work ribbon for logs, connections, or
   traffic.
5. Revalidate resize behavior and keyboard traversal.

## Open Questions

- Whether `Activity` and `Diagnostics` stay separate top-level destinations or
  share one support route plus tabs.
- Whether the lower live-work ribbon should be always visible or collapsed by
  default on medium desktop widths.
