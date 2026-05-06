# WB Stream Compatibility Contract

## Scope

This contract covers the first `wb-stream` provider slice for the public
`https://stream.wb.ru/` surface.

It is intentionally limited to:

- operator-provided room or meeting URLs rooted at `https://stream.wb.ru/`
- narrow, fixture-backed URL-shape validation
- normalization into a `conference_room` artifact
- the external `open_room` action surface
- explicit provider-stage failures for malformed or unsupported links

It explicitly excludes:

- generic TURN credential extraction
- same-device media execution
- embedded browser support
- headless page scraping or WBAAS anti-bot bypass
- account creation or phone-code automation
- recording, chat, or provider-token export

## URL-shape baseline

The committed first slice accepts only two-segment room paths under the exact
host:

- `https://stream.wb.ru/rooms/{room}`
- `https://stream.wb.ru/room/{room}`
- `https://stream.wb.ru/meeting/{room}`
- `https://stream.wb.ru/meetings/{room}`
- `https://stream.wb.ru/join/{room}`

The room segment is constrained to a conservative ASCII identifier shape. Query
strings, fragments, userinfo, explicit ports, extra path segments, and alternate
hosts fail closed before any browser, HTTP fetch, or local runtime action is
attempted.

## First scenarios

### `wb_stream_room_link_success_v1`

Input contract:

- provider: `wb-stream`
- accepted input is a room URL under `https://stream.wb.ru/`
- ordinary artifact input stores only a redacted room-link shape

Expected behavior:

- the provider records one synthetic `wb_stream_room_link` parse stage
- the provider returns a `conference_room` outcome
- the normalized room URL is available only as the typed room action target
- no `generic_turn` credential output is returned

### `wb_stream_room_link_rejected_v1`

Input contract:

- malformed or unsupported room URLs may contain secret-looking query,
  fragment, or userinfo material

Expected behavior:

- the provider fails at `wb_stream_room_link`
- the machine-readable error code is `invalid_room_link`
- sanitized artifacts do not persist raw secret-looking input fragments
- no browser, HTTP, TURN, DTLS, or session transport fallback is attempted
