## 1. Information architecture
- [ ] 1.1 Define the new primary mobile destination set around `Home`,
      `Profiles`, `Routing`, and support-oriented activity/diagnostics surfaces.
- [ ] 1.2 Replace the current diagnostics-first root shell with a VPN-first
      navigation structure that works on phone-sized layouts.
- [ ] 1.3 Verify that wider mobile or tablet layouts adapt the same shell
      structure without collapsing back into one stacked dashboard.

## 2. Home surface
- [ ] 2.1 Build a VPN-first home that shows the selected profile, runtime mode,
      scope summary, compact live status, and one dominant start or disconnect
      action.
- [ ] 2.2 Add a product-grade empty state for the no-profile path with explicit
      add and import actions.
- [ ] 2.3 Remove large inline profile/provider editing and raw diagnostic
      content from the default home payload.

## 3. Dedicated workflow surfaces
- [ ] 3.1 Move saved profile management into a dedicated profile destination
      with selection, add, import, and edit entry points.
- [ ] 3.2 Move per-app routing into a dedicated searchable routing surface with
      explicit include, exclude, and all-apps scope presentation.
- [ ] 3.3 Keep runtime mode and scope copy honest for `android_vpn_service` and
      future non-system Android modes.

## 4. Support surfaces and validation
- [ ] 4.1 Keep activity, logs, and diagnostics reachable as explicit secondary
      support surfaces with drill-down from home.
- [ ] 4.2 Update mobile widget, navigation, and interaction tests for the new
      home, profiles, routing, and disconnect/start flows.
- [ ] 4.3 Run `openspec validate add-29-mobile-vpn-product-shell --strict
      --no-interactive`.
