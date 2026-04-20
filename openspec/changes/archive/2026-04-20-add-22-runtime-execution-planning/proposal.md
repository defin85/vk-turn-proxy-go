# Change: [22] Add runtime execution planning umbrella

## Why
`add-20-multi-provider-runtime-families` made provider resolution honest about artifact families, and `add-17` plus `add-18` define the first packaged platform-tunnel ready paths.
What is still missing is the contract between those two layers.

Today the repository can describe what a provider resolved and can separately describe whether a host owns a system tunnel mode, but it still lacks one typed way to say how a resolved artifact becomes a native same-device execution path.
Without that layer the product will either hard-code `WireGuard-over-TURN` assumptions into every future host change or overstate support for very different paths such as in-call `WebRTC` data channels or HTTPS-like tunnel runtimes.

## Sequence
- Order: `22`
- Depends on: `add-05-platform-tunnel-integrations`, `add-20-multi-provider-runtime-families`
- Unblocks: follow-on native execution engines, carrier families beyond TURN, and explicit same-device runtime planning for `add-17` and `add-18`

## What Changes
- Add one typed runtime-execution-planning contract that keeps provider `access_method`, byte `carrier_family`, native `engine_family`, and optional `host_adapter` separate instead of collapsing them into one mode string.
- Extend provider runtime artifacts so resolved artifacts advertise the typed access methods that a host-owned same-device action may consume.
- Extend the client control plane so hosts can negotiate runtime-execution-planning explicitly and return typed execution plans for host-owned same-device actions.
- Define that the first supported packaged system-tunnel ready paths stay scoped to documented TURN-backed `wireguard_native` plans, while `webrtc_datachannel`, foreign-core proxy adapters, and HTTPS-like tunnel plans remain explicitly capability-gated.
- Define that carrier families keep distinct remote endpoint ownership so TURN plans stay on the current `tunnel-server` family and future `WebRTC` or HTTPS-like carriers do not pretend that the same server role already exists.

## Impact
- Affected specs: `runtime-execution-planning` (new), `provider-runtime-artifacts`, `client-control-plane`, `platform-tunnel-integration`
- Affected code: future `internal/provider` artifact surfaces, `pkg/clientcontrol`, `cmd/clientd`, packaged mobile and desktop hosts, transport/runtime planning docs, and future carrier-specific remote endpoints
