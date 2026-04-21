## 1. Visual contract
- [ ] 1.1 Define the mobile shell as the approved visual reference for the
      desktop shell while keeping desktop-first information architecture.
- [ ] 1.2 Define which visual primitives become shared cross-shell tokens or
      components and which wrappers remain desktop-local.
- [ ] 1.3 Define how ready, blocked, active-runtime, and support-oriented
      states stay visually recognizable across desktop and mobile.

## 2. Shared and desktop UI implementation
- [ ] 2.1 Add shared visual primitives to `packages/flutter_shell_core`
      without moving desktop/mobile-specific chrome or layout ownership there.
- [ ] 2.2 Restyle the desktop shell's high-salience surfaces, including
      workbench chrome, cards, forms, and status treatments, into the shared
      product family.
- [ ] 2.3 Preserve desktop density, keyboard traversal, and resize behavior
      while applying the aligned visual system.

## 3. Verification
- [ ] 3.1 Add or update desktop widget and reference/screenshot coverage for
      the harmonized visual system.
- [ ] 3.2 Cross-check the resulting desktop shell against the mobile reference
      and desktop-first expectations instead of stretched mobile layout rules.
- [ ] 3.3 Run `openspec validate refactor-42-flow-1-desktop-core-desktop-mobile-visual-alignment --strict --no-interactive`.
