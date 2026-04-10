## 1. Verification Workflow
- [ ] 1.1 Document the repo-owned operator workflow for capturing a fresh
      VK-derived `generic-turn://...` link, recording the derived expiry
      boundary, and re-running the same check after expiry plus grace
- [ ] 1.2 Capture redacted evidence for one live sample that shows pre-expiry
      fresh Allocate success and post-expiry fresh Allocate failure
- [ ] 1.3 Validate `add-18-vk-derived-expiry-verification` with
      `openspec validate add-18-vk-derived-expiry-verification --strict --no-interactive`
