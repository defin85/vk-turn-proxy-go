# Compatibility Instructions

Use these rules for any work under `test/compatibility/` and for any change that makes a compatibility or wire-behavior claim.

## Start here

- `test/compatibility/README.md`
- the provider-specific contract, for example `test/compatibility/vk/README.md`
- the relevant schema, fixtures, and replay tests
- the matching `openspec/specs/*/spec.md`

## Rules

- Define or update the compatibility scenario before changing wire behavior.
- Treat committed fixtures and replayable evidence as the compatibility contract.
- Confirm claims in at least two sources: contract doc + code/test.
- Do not claim compatibility from code inspection, TODOs, or a manual live run alone.
- Keep committed fixtures sanitized and replayable.
- Record intentional deviations explicitly instead of silently drifting from the oracle.

## When updating artifacts

- Update schema, template/example, fixture, and test together when the contract changes.
- Preserve stable `scenario_id` values unless the scenario semantics changed.
- Keep redaction placeholders descriptive and stable.
- For VK work, keep provider-only contour evidence separate from runtime evidence.

## Verification

- Provider contour and fixture parsing: `go test ./internal/provider/vk ./cmd/probe`
- VK runtime evidence and replay: `go test ./test/compatibility/vk/runtime -run 'TestRuntimeEvidence(Assets|Replay)'`
- Shared runtime or transport changes: escalate to `go test ./...` and `go build ./...`

## Oracle

The legacy repository `/home/egor/code/vk-turn-proxy` remains the compatibility oracle until equivalent coverage exists here.
