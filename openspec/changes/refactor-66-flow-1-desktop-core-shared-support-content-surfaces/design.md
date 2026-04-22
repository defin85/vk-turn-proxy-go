## Context

Support ownership already differs for good product reasons:

- desktop exposes support detail as an optional inspector or support route;
- mobile exposes support as a dedicated workflow with compact and wide
  presentations.

The repeated part is not the wrapper. It is the activity and diagnostics
content inside that wrapper.

## Goals / Non-Goals

- Goals:
  - share one support-content layer across desktop and mobile;
  - keep desktop inspector ownership and mobile support destination ownership
    unchanged;
  - reduce drift in activity and diagnostics presentation.
- Non-Goals:
  - merge inspector and mobile support shells into one route model;
  - move mobile-specific embedded-browser reset controls into shared code;
  - refactor routing in the same change.

## Decisions

- Decision: share content bodies, not support wrappers.
  - Why: the wrapper difference is intentional product structure, while the
    content difference is mostly accidental duplication.
  - Alternatives considered:
    - share the full support page and inspector shell: rejected because desktop
      and mobile intentionally own different support shells.

- Decision: keep support-context badges and shell triggers local unless they
  become truly identical later.
  - Why: they still depend on shell-level context and available chrome.
  - Alternatives considered:
    - push all support chrome into shared core: rejected as a likely regression
      of platform fit.

## Risks / Trade-offs

- Shared support bodies may still need more width hooks than `Home`,
  `Profiles`, or `Providers`.
- Desktop inspector density and mobile touch ergonomics could pull the shared
  content in different directions if the API boundary is not explicit enough.

## Migration Plan

1. Introduce shared support-content APIs in `flutter_shell_core`.
2. Move common activity and diagnostics bodies there.
3. Rewire desktop inspector content to the shared layer.
4. Rewire mobile support workflow content to the shared layer while keeping
   wrappers local.

