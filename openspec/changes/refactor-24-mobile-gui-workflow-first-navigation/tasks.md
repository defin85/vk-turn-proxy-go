## 1. Navigation contract
- [ ] 1.1 Replace the monolithic mobile dashboard with workflow-first navigation
      or drill-down destinations for home, activity, and diagnostics.
- [ ] 1.2 Remove fixed-height stacked panel assumptions from the primary mobile
      flow.
- [ ] 1.3 Keep blocked/incompatible host and tunnel summaries explicit from the
      primary mobile surface.

## 2. Shell implementation
- [ ] 2.1 Refactor mobile `DashboardPage` composition into mobile-sized
      destinations without changing control-plane behavior.
- [ ] 2.2 Refactor `ProfileEditorPanel` so advanced runtime/provider content is
      progressively disclosed instead of always inline.
- [ ] 2.3 Reduce action density in resolution/session UI by promoting one clear
      primary action and moving secondary actions into compact affordances.

## 3. Verification
- [ ] 3.1 Add or update mobile widget coverage for the new primary flow,
      blocked/error visibility, and secondary activity/diagnostic navigation.
- [ ] 3.2 Run `cd mobile/gui_shell && flutter analyze && flutter test`.
- [ ] 3.3 Run `openspec validate refactor-24-mobile-gui-workflow-first-navigation --strict --no-interactive`.
