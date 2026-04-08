## 1. Overlay contract and config
- [x] 1.1 Define client and server config surface plus the explicit ingress -> egress support matrix without breaking current UDP defaults
- [x] 1.2 Define the underlay-neutral overlay session/frame model for datagram and stream classes, including identity and teardown semantics

## 2. Runtime plumbing
- [x] 2.1 Refactor session and routing plumbing from datagram-only `RelayPacket{Payload, ReplyTo}` assumptions to adapter-aware overlay envelopes while preserving the current UDP baseline
- [x] 2.2 Introduce client ingress adapter and server egress adapter interfaces plus repository-owned overlay envelope types and UDP reference adapters
- [x] 2.3 Implement the first native stream slice for `tcp -> tcp` over the existing underlay with explicit cleanup and backpressure handling

## 3. Evidence and docs
- [x] 3.1 Add deterministic unit and integration coverage for the UDP baseline through the adapter layer and for the first native TCP slice
- [x] 3.2 Update runtime docs and compatibility notes to list supported adapter pairs, state that support is pair-specific, and explicitly exclude unfinished adapters such as SOCKS5, HTTP CONNECT, and TUN

## 4. Verification
- [x] 4.1 Run the smallest relevant adapter/session/transport test set
- [x] 4.2 Run `go test ./...`
- [x] 4.3 Run `go build ./...`
- [x] 4.4 Run `openspec validate add-04-native-transport-overlay --strict --no-interactive`
