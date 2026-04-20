## Context

The repository already has two Flutter shells in one shared workspace. They
share meaningful domain logic, but their visual language is still drifting.

The mobile shell now provides the strongest product reference in practice:

- clearer status language
- stronger surface hierarchy
- more coherent action emphasis
- better-feeling forms and operator flow polish

The desktop shell has already gone through multiple information-architecture
refactors and is moving toward a workbench shape, but visual alignment with
mobile has not yet been treated as a first-class change.

## Goals / Non-Goals

- Goals:
  - Align desktop with the same product visual family already established in
    mobile.
  - Reuse shared visual primitives where that reduces drift.
  - Keep desktop unmistakably desktop-first in layout and interaction.
  - Make status, support, and action emphasis feel recognizably related across
    both shells.
- Non-Goals:
  - Reopen desktop information architecture that belongs in
    `add-30-desktop-vpn-workbench-shell`.
  - Force desktop into phone navigation, phone density, or mobile-only motion
    patterns.
  - Merge desktop and mobile into one app package.
  - Restyle every low-salience edge case in one pass before the high-salience
    product surfaces are aligned.

## Decisions

### Decision: Mobile is the visual reference, not the layout template

Desktop should inherit the mobile shell's product language:

- semantic color use
- surface hierarchy
- status treatment grammar
- action emphasis
- core control styling

But desktop must keep desktop-first affordances such as stable navigation,
dense work surfaces, keyboard-first interaction, and resize-aware composition.

### Decision: Shared visual primitives live in flutter shell core

When both shells need the same platform-neutral visual primitive, it should
live in `packages/flutter_shell_core`.

Examples include:

- semantic color and tone tokens
- shared status treatments
- shared action emphasis patterns
- platform-neutral card or form styling primitives

Platform-specific chrome and layout wrappers remain app-local.

### Decision: First alignment focuses on high-salience surfaces

The first pass should align the surfaces that define product feel:

- shell chrome
- dominant workbench surfaces
- forms and cards
- notices and status treatments

That gives the largest user-visible improvement before secondary and rarely
visited surfaces are tuned.

### Decision: Visual consistency should reinforce, not erase, desktop affordances

Desktop should look like the same product as mobile, but the aligned style must
still support:

- denser information display
- pointer and keyboard ergonomics
- large-window composition
- inspector and side-surface behavior

## Risks / Trade-offs

- Risk: visual alignment can accidentally turn desktop into a stretched mobile
  layout.
  Mitigation: keep workbench structure and desktop interaction patterns
  explicitly out of scope for replacement.
- Risk: over-extracting shared UI can move platform-specific wrappers into
  shared code too early.
  Mitigation: share primitives and treatments, not desktop/mobile chrome.
- Risk: future mobile polish can drift again if the shared visual contract is
  too vague.
  Mitigation: define explicit shared tokens and high-salience component rules.

## Migration Plan

1. Define the cross-shell visual contract and shared-vs-local ownership.
2. Extract or formalize shared product primitives in `flutter_shell_core`.
3. Restyle desktop high-salience workbench surfaces to the aligned language.
4. Expand coverage and reference assets so drift is detectable.

## Open Questions

- Whether `add-30-desktop-vpn-workbench-shell` should land first as a hard
  dependency or whether some visual primitives can be prepared in parallel.
- Which current mobile surfaces should become the canonical screenshot or
  reference asset set for desktop alignment review.
