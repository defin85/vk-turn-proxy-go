# Change: [34] Refocus mobile Providers on saved providers

## Why
The current mobile `Providers` destination mixes three different layers on the
same root surface: saved provider records, preset bootstrap cards, and a full
inline editor.
That makes the screen feel heavier than `Profiles`, hides the real primary
entity, and leaks internal architecture language such as `App-owned provider
catalog` into operator-facing UI.

The product intent is simpler: open `Providers`, see your reusable providers,
then explicitly choose whether to create, edit, or bootstrap a new one.
Presets still matter, but they are accelerators for creation rather than the
main thing the root page should be about.

## Sequence
- Order: `34`
- Depends on: `add-29-mobile-vpn-product-shell`
- Unblocks: scalable provider-template UX, cleaner provider taxonomy copy, and
  a `Providers` surface that matches the list-first mental model already used by
  `Profiles`

## What Changes
- Redefine the top-level mobile `Providers` destination as a list-first surface
  whose primary content is saved managed provider records.
- Move provider presets into an explicit create flow so the root page does not
  turn into a long preset catalog when more templates are shipped.
- Clarify that the app-owned provider catalog remains an internal shell-owned
  taxonomy, while operator-facing UI should talk about `Provider family` and
  `Templates`.
- Allow the editor to appear as drill-down detail on phone and as list-detail
  companion content on wider mobile layouts without replacing the list-first
  root.

## Impact
- Affected specs: `mobile-gui-client`
- Affected code: `mobile/gui_shell/lib/src/ui/dashboard_page.dart`,
  `mobile/gui_shell/lib/src/ui/provider_config_editor.dart`,
  `mobile/gui_shell/test/widget_test.dart`, `mobile/gui_shell/README.md`, and
  related mobile-shell controller/view-model glue
