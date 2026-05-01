## Context

`add-73` introduced a generic VPN transport profile store and explicitly said
that `wireguard_native_v1` is the first concrete kind, not the permanent store
contract. `add-74` added structured editing, but the shipped editor and typed
Flutter models still mirror WireGuard fields directly. `add-75` moved native
VPN lifecycle ownership into RelayDock, which makes the UI boundary more
important: operators should manage VPN setup in RelayDock, but the shell should
not encode WireGuard as the only possible VPN transport forever.

The current state is intentionally narrow:

- supported packaged native VPN startup is still TURN-backed
  `wireguard_native`;
- `wireguard_conf` remains an import adapter into `wireguard_native_v1`;
- the Flutter editor fields, generated-key handling, labels, and default draft
  construction are WireGuard-shaped;
- the current UI mostly edits the active required profile and does not yet
  provide a first-class library for choosing among multiple transport profiles;
- unknown profile kinds are not yet safe enough for a host-advertised future
  profile schema.

## Goals / Non-Goals

Goals:

- Make the shell profile editor render from host-advertised schema descriptors.
- Provide a profile manager/list for multiple VPN transport profiles without
  mixing them into provider/application profiles.
- Make profile kinds and import adapters extensible without breaking host
  negotiation when a future kind is advertised.
- Preserve fail-closed startup: a non-WireGuard kind is not startable until its
  execution plan, materializer, host/native adapter, and tests exist.
- Keep secrets write-only and host-owned for every profile kind, not just
  WireGuard.
- Keep the RelayDock IA decision from add-75: Home owns connect/disconnect;
  Routing and diagnostics show status and setup links.

Non-goals:

- Implement OpenVPN, TrustTunnel, proxy-core, or another concrete VPN transport
  in this change.
- Make experimental or foreign-core plans default system-tunnel paths.
- Export secret-bearing profile material.
- Reinterpret WebRTC datachannel research as Android `VpnService` support.

## Decisions

### Decision: Profile kind values are open but startability is closed

The control plane and shell clients should parse unknown profile kinds without
dropping the whole host capability response. Unknown kinds may be displayed as
host-advertised setup metadata when a schema is available, but they are not
startable unless the runtime execution matrix declares a supported plan and the
host proves materialization.

This preserves future extensibility without making "unknown" mean "trusted".

### Decision: Structured editor fields come from schema descriptors

The editor should render supported fields from descriptors, not from
WireGuard-specific widget code. Field descriptors remain machine-readable and
stable, while labels and layout can be localized by the shell.

The renderer should cover the common value kinds already in the contract:
string, string list, integer, and secret string. Secret fields use explicit
actions such as preserve, replace, or generate when advertised by the host.
Unsupported fields are shown only as read-only/blocked metadata or omitted with
an explicit setup reason; they must not be silently submitted.

Structured drafts should become a field-value map keyed by stable field ids,
plus a separate secret-action map keyed by the same ids. New non-WireGuard
kinds must not be forced through the current WireGuard-shaped draft fields.

Host-provided display names, helper text, grouping hints, and validation
messages are untrusted display metadata. Shells may render them as plain text
after localization/sanitization, but must not treat them as executable links,
markup, commands, or proof that a value is safe to store or start.

### Decision: Import adapters stay kind-specific

The shell must select import affordances from host-advertised adapters. A
WireGuard `.conf` button must not appear for a non-WireGuard required kind
unless the host explicitly advertises an adapter that produces that kind.
Unknown adapters are not executable unless the shell supports the advertised
material acquisition method, such as plain text paste, file picker with
declared extensions, QR payload, or provider-managed enrollment.

### Decision: Runtime plans remain the startability boundary

A profile kind being editable is not enough to start VPN. Startup remains bound
to a runtime execution plan that declares access method, carrier family, engine
family, host adapter, and required profile kinds. Later concrete transports
must add their own plan compatibility edge and host/native adapter evidence.

### Decision: Multiple transport profiles use a scoped manager

RelayDock should support multiple VPN transport profiles as host-owned
transport material records. The primary library surface belongs to the VPN
transport setup flow, reachable from Home when startup is blocked and from
Routing when the operator is inspecting tunnel status or route policy.

This manager lists redacted profiles, filters or groups by kind and compatible
execution plan, and lets the operator create, import, edit, forget, validate,
and select a profile for startup or scoped default binding when those actions
are advertised by the host.

Provider/application `Profiles` remain separate from VPN transport profiles.
They may link to the relevant VPN transport manager when a selected product
profile requires native VPN material, but they must not become the source of
truth for transport secrets or default transport selection.

### Decision: Transport profile material stays separate from route policy

Platform route scope, Android app-scope policy, underlay socket protection, and
permission lifecycle remain platform-tunnel concerns. A profile schema may
describe engine material, but it must not silently override RelayDock routing
policy or become a second source of truth for app scope.

## Risks / Trade-offs

- Risk: making kinds open can hide typos in host responses. Mitigation: unknown
  kinds are display/setup-only unless an advertised schema, lifecycle actions,
  and supported runtime plan all line up.
- Risk: a fully generic editor can become awkward for WireGuard. Mitigation:
  allow field ordering, grouping, labels, helper text, and action metadata to be
  host- or shell-defined while preserving stable field ids.
- Risk: a schema-driven UI may overclaim support for a new transport before the
  native adapter exists. Mitigation: separate editable profile support from
  runtime startability and require repo-owned smoke evidence for every new
  engine/profile kind combination.
- Risk: host-advertised UI metadata can become an injection or phishing vector.
  Mitigation: render metadata as inert text, keep validation authority in the
  host, and never execute links or commands from schema descriptors.
