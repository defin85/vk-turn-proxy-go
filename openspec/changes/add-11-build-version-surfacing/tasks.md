## 1. Contract
- [x] 1.1 Define the canonical split between control-plane contract version and human-facing product/build identity
- [x] 1.2 Define the structured version manifest with build number and the shared host/build metadata shape that the GUI and diagnostics consume

## 2. Build and Runtime Plumbing
- [x] 2.1 Add a repo-managed version source and validate it in repo-owned build workflows
- [x] 2.2 Stamp Go binaries and Flutter GUI artifacts with consistent product version and build metadata
- [x] 2.3 Extend the local control plane so host build identity is exposed separately from negotiation version
- [x] 2.4 Extend diagnostics export so session bundles carry GUI build identity, host build identity, and contract version context

## 3. GUI Surfacing
- [x] 3.1 Show the local GUI version/build identity in the desktop shell
- [x] 3.2 Show the connected host version/build identity and contract version distinctly in the desktop shell
- [x] 3.3 Keep incompatible-host reporting explicit while still surfacing the detected host identity when available

## 4. Verification
- [x] 4.1 Add or update tests for host info version/build metadata handling
- [x] 4.2 Add or update GUI tests for visible app/host version labels
- [x] 4.3 Run the smallest relevant verification set, then `go test ./...`, and `go build ./...`
