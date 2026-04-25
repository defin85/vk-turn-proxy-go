## 1. Desktop routing IA
- [ ] 1.1 Add an application-routing section to the desktop Routing workbench
      that is separate from IP routing and advanced runtime settings
- [ ] 1.2 Render unavailable, prerequisite-blocked, and supported states from
      host capability metadata
- [ ] 1.3 Keep Android package-routing UI in the mobile shell unchanged

## 2. App inventory and selection
- [ ] 2.1 Render host-provided desktop app inventory with display name,
      identity type, path or platform id when available, and enforceability
      state
- [ ] 2.2 Support all-app, selected-app include, and selected-app exclude
      policy choices only when the host advertises them
- [ ] 2.3 Persist selected desktop app selectors as profile intent while
      treating stale selectors as host-validated startup failures

## 3. Runtime state and copy
- [ ] 3.1 Show that changing desktop app scope requires reconnect or a new
      startup attempt until live mutation is specified
- [ ] 3.2 Add localized copy for supported, unavailable, blocked, stale, and
      reconnect-required states
- [ ] 3.3 Add diagnostics entry points for host-reported classifier and
      enforcement failures without turning the Routing page into a log viewer

## 4. Tests and validation
- [ ] 4.1 Add desktop widget tests for unsupported host, blocked host,
      supported inventory, selected app policy, and reconnect-required state
- [ ] 4.2 Run desktop and shared Flutter checks selected from
      `docs/agent/verification.md`
- [ ] 4.3 Run
      `openspec validate add-70-flow-9-desktop-app-routing-workbench-ui --strict --no-interactive`
