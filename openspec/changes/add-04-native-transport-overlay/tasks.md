## 1. Overlay contract and config
- [ ] 1.1 Define client and server config surface for selecting ingress and egress adapters without breaking current UDP defaults
- [ ] 1.2 Define the overlay session/frame model for datagram and stream classes, including identity and teardown semantics

## 2. Runtime plumbing
- [ ] 2.1 Refactor session and routing plumbing from datagram-only `RelayPacket{Payload, ReplyTo}` assumptions to adapter-aware overlay envelopes while preserving the current UDP baseline
- [ ] 2.2 Introduce client ingress adapter and server egress adapter interfaces plus UDP reference adapters
- [ ] 2.3 Implement the first native stream slice for `tcp -> tcp` over the existing underlay with explicit cleanup and backpressure handling

## 3. Evidence and docs
- [ ] 3.1 Add deterministic unit and integration coverage for the UDP baseline through the adapter layer and for the first native TCP slice
- [ ] 3.2 Update runtime docs and compatibility notes to list supported adapter pairs and explicitly exclude unfinished adapters such as SOCKS5, HTTP CONNECT, and TUN

## 4. Verification
- [ ] 4.1 Run the smallest relevant adapter/session/transport test set
- [ ] 4.2 Run `go test ./...`
- [ ] 4.3 Run `go build ./...`
- [ ] 4.4 Run `openspec validate add-04-native-transport-overlay --strict --no-interactive`
