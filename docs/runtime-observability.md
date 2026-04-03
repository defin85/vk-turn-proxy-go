# Runtime Observability

Long-running binaries expose a small runtime observability surface for operators and tests.

## Structured events

Client and server runtimes emit structured log records with stable field names:

- `event`
- `runtime`
- `session_id`
- `provider`
- `turn_mode`
- `peer_mode`
- `stage`
- `result`

Additional low-cardinality fields may appear when relevant:

- `listen`
- `peer`
- `turn_addr`
- `resolution_method`
- `connections`
- `worker`
- `ready_workers`
- `restart`
- `backoff`

Sensitive inputs are redacted before they reach structured runtime events:

- VK invite tokens
- TURN usernames and passwords
- token-like query parameters such as `access_token`

## Metrics surface

`cmd/tunnel-client` and `cmd/tunnel-server` expose `/metrics` when started with `-metrics-listen <addr>`.

Example:

```bash
go run ./cmd/tunnel-client -provider generic-turn -link 'generic-turn://user:pass@127.0.0.1:3478' -peer 127.0.0.1:56000 -metrics-listen 127.0.0.1:9100
curl -s http://127.0.0.1:9100/metrics
```

The first metric set is intentionally small:

- `vk_turn_proxy_runtime_session_starts_total`
- `vk_turn_proxy_runtime_session_failures_total`
- `vk_turn_proxy_runtime_startup_stage_failures_total`
- `vk_turn_proxy_runtime_active_workers`
- `vk_turn_proxy_runtime_forwarded_packets_total`
- `vk_turn_proxy_runtime_forwarded_bytes_total`

Allowed label dimensions are:

- `runtime`
- `provider`
- `turn_mode`
- `peer_mode`
- `stage`
- `direction`

`session_id` is intentionally excluded from metrics to keep cardinality low.

## Operator workflow

1. Start the runtime with `-metrics-listen`.
2. Tail structured logs and filter by `session_id` when investigating one runtime attempt.
3. Inspect `/metrics` for startup-stage failures, active workers, and forwarding counters.
4. Compare stage names with the documented runtime stage taxonomy in the client runtime spec.
