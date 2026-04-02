## 1. Compatibility baseline

- [x] 1.1 Define the first VK compatibility scenario and fixture format based on the legacy `getVkCreds` flow.
- [x] 1.2 Capture or reconstruct sanitized stage responses that cover a successful VK invite resolution and at least one explicit provider failure.

## 2. Debug contour implementation

- [x] 2.1 Implement VK invite normalization and staged credential resolution inside `internal/provider/vk` with injectable HTTP dependencies for tests.
- [x] 2.2 Extend `cmd/probe` to persist sanitized stage artifacts under `ProbeConfig.OutputDir` and print a normalized summary for operators.
- [x] 2.3 Ensure provider failures stay explicit and fail closed when required VK response fields are missing or malformed.

## 3. Verification and handoff

- [x] 3.1 Add compatibility and unit tests for success, malformed invite input, and provider-stage failures.
- [x] 3.2 Document how to run the VK debug contour and how its artifacts feed the next legacy-to-Go porting steps.
