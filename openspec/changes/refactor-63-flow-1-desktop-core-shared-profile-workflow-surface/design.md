## Context

The repository already proved the narrow shared extraction pattern with the
`Home` surface and then quieted the desktop shell by separating `Profiles` and
`Providers` at the route layer.

What still remains duplicated is the profile workflow body:

- draft field editing and controller sync;
- managed-provider versus custom-provider mode switching;
- save, reset, resolve, and start actions;
- portable profile transfer entry state.

## Goals / Non-Goals

- Goals:
  - move one shared profile workflow body into `flutter_shell_core`;
  - keep desktop and mobile shell ownership intact;
  - reduce profile-behavior drift before extracting more shared primitives.
- Non-Goals:
  - merge desktop and mobile route models;
  - move platform-native transfer adapters into shared code;
  - refactor provider workflow, support, or routing in the same change.

## Decisions

- Decision: extract the profile workflow body, not the full page shell.
  - Why: both apps need the same editor body, but not the same page scaffold.
  - Alternatives considered:
    - keep separate profile editors and only share more helper functions:
      rejected because the current duplication is already at the surface level.
    - share the full page including mobile app bar or desktop route chrome:
      rejected because that would violate app-local shell ownership.

- Decision: keep portable transfer adapters app-local.
  - Why: mobile and desktop use different share, QR, file, and browser entry
    points around the same profile payload semantics.
  - Alternatives considered:
    - move transfer UI wrappers into shared code: rejected because they depend
      on platform-native plugins and shell-local flows.

## Risks / Trade-offs

- The shared profile surface could become over-parameterized if every app-local
  nuance is pushed into one widget API.
- Desktop might lose some density if the shared profile body follows the mobile
  layout too literally.
- Mobile could regress if current-profile targeting or profile-root actions
  become entangled with the shared editor body.

## Migration Plan

1. Define a shared profile workflow API in `flutter_shell_core`.
2. Move the common body-level profile editor into that shared package.
3. Rewire mobile profile workspace to the shared body while keeping app-local
   transfer and navigation wrappers.
4. Rewire desktop `Profiles` canvas to the shared body and update tests.
