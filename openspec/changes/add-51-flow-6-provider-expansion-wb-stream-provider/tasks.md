## 1. Contract
- [x] 1.1 Add a `wb-stream-provider` capability for the provider descriptor,
      typed stream.wb.ru URL entry contract, redacted ordinary reads, and
      fail-closed behavior.
- [x] 1.2 Bind successful WB Stream room-link resolution to the
      `conference_room` artifact family and the committed external `open_room`
      action surface.
- [x] 1.3 Declare `guest_or_account` auth posture and external browser/app
      ownership explicitly; keep embedded-browser, headless scraping, account
      automation, local conference execution, and `generic-turn` export out of
      scope.

## 2. Evidence and rollout
- [x] 2.1 Require descriptor and shell rollout to stay behind the flow-6
      shipping gate until WB-specific evidence exists for the exact
      `https://stream.wb.ru/` surface.
- [x] 2.2 Define fail-closed handling for malformed room links, WBAAS anti-bot
      challenge boundaries, missing external-browser support, blocked auth, and
      incomplete provider flows.
- [x] 2.3 Record fixtures or live evidence for accepted and rejected WB Stream
      URL shapes before promoting the provider into the ordinary shipped
      catalog.

## 3. Validation
- [x] 3.1 Run focused provider/runtime artifact tests for WB descriptor,
      URL normalization, redaction, and conference-room action mapping.
- [x] 3.2 Run focused desktop and mobile shell tests for the external open-room
      action and no-tunnel/no-local-execution copy.
- [x] 3.3 Run
      `openspec validate add-51-flow-6-provider-expansion-wb-stream-provider --strict --no-interactive`
