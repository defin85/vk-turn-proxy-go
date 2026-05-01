## 1. Control-plane contracts

- [x] 1.1 Replace closed transport profile kind parsing in Go/Flutter clients
      with unknown-safe typed values that preserve the raw host-advertised
      value.
- [x] 1.2 Replace WireGuard-shaped structured draft DTOs with a generic
      field-value map plus secret-action map keyed by stable field ids, while
      preserving `wireguard_native_v1` compatibility.
- [x] 1.3 Extend structured field descriptors with enough presentation and
      validation metadata for non-WireGuard schemas without adding
      transport-specific UI code.
- [x] 1.4 Ensure import adapter descriptors are kind-specific, declare a
      supported material acquisition method, and fail closed when the required
      kind has no advertised adapter.
- [x] 1.5 Add control-plane tests for unknown profile kinds, unknown import
      adapters, unsupported schema fields, and redacted secret status.

## 2. Schema-driven profile editor

- [x] 2.1 Replace the WireGuard-only editor widget with a schema renderer for
      string, string-list, integer, and secret-string fields.
- [x] 2.2 Implement secret update actions from schema metadata for create and
      update flows, including preserve/replace/generate when advertised.
- [x] 2.3 Keep WireGuard-specific conveniences as schema/default metadata, not
      hard-coded assumptions in the shared editor.
- [x] 2.4 Treat schema labels, helper text, grouping hints, and validation
      messages as inert display text; do not render host-provided markup,
      commands, or executable links.
- [x] 2.5 Add Flutter tests proving an artificial non-WireGuard schema can be
      rendered, validated, saved, and rejected when unsupported.
- [x] 2.6 Add a shared VPN transport profile manager/list surface that can show
      multiple redacted profiles, filter by required kind/execution plan, and
      invoke host-advertised create/import/edit/forget/validate/select actions.

## 3. Runtime and host boundaries

- [x] 3.1 Keep `wireguard_native_v1` as the only startable native VPN profile
      kind until a later concrete transport change adds implementation
      evidence.
- [x] 3.2 Add runtime execution tests that editable non-WireGuard profile kinds
      do not become startable without an explicit supported plan.
- [x] 3.3 Keep platform tunnel status and diagnostics profile-kind aware without
      leaking raw profile material.
- [x] 3.4 Preserve Home as the single connect/disconnect owner; Routing and
      diagnostics may only expose status and setup/edit/import/forget links.
- [x] 3.5 Keep platform route scope, app-scope policy, underlay socket
      protection, and VPN permission lifecycle outside transport profile
      schemas.
- [x] 3.6 Keep provider/application profiles separate from VPN transport
      profiles; product Profiles may link to the transport manager but must not
      own transport secret state or default selection.

## 4. Verification

- [x] 4.1 Rebase the proposal against current specs after add-73/add-74/add-75
      are archived or explicitly accepted as the implementation baseline.
- [x] 4.2 Run targeted Go tests for `pkg/clientcontrol` and any touched host
      adapter packages.
- [x] 4.3 Run Flutter analyze/tests for `packages/flutter_shell_core`,
      `mobile/gui_shell`, and `desktop/gui_shell`.
- [x] 4.4 Run `openspec validate add-76-relaydock-schema-driven-vpn-transport-profiles --strict --no-interactive`.
- [x] 4.5 Before claiming non-WireGuard support, add a concrete follow-up change
      with device/runtime smoke evidence for that specific profile kind and
      engine family.
