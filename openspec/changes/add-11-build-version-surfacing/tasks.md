## 1. Contract
- [ ] 1.1 Define the canonical split between control-plane contract version and human-facing product/build identity
- [ ] 1.2 Define the shared host/build metadata shape that the GUI consumes

## 2. Build and Runtime Plumbing
- [ ] 2.1 Add a repo-managed version source and validate it in repo-owned build workflows
- [ ] 2.2 Stamp Go binaries and Flutter GUI artifacts with consistent product version and build metadata
- [ ] 2.3 Extend the local control plane so host build identity is exposed separately from negotiation version

## 3. GUI Surfacing
- [ ] 3.1 Show the local GUI version/build identity in the desktop shell
- [ ] 3.2 Show the connected host version/build identity and contract version distinctly in the desktop shell
- [ ] 3.3 Keep incompatible-host reporting explicit while still surfacing the detected host identity when available

## 4. Verification
- [ ] 4.1 Add or update tests for host info version/build metadata handling
- [ ] 4.2 Add or update GUI tests for visible app/host version labels
- [ ] 4.3 Run the smallest relevant verification set, then `go test ./...`, and `go build ./...`
