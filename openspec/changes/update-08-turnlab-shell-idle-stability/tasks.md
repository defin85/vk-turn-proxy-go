## 1. Contract
- [ ] 1.1 Define the manual turnlab shell idle-window contract for desktop GUI testing

## 2. Implementation
- [ ] 2.1 Add configurable peer idle timeout support to the turnlab harness
- [ ] 2.2 Give `cmd/turnlab-shell` a manual-friendly default idle timeout plus an explicit override flag
- [ ] 2.3 Document the shell idle policy and the manual desktop GUI workflow

## 3. Verification
- [ ] 3.1 Add tests for custom harness peer idle timeout behavior
- [ ] 3.2 Add shell tests covering the manual idle-timeout default and override path
- [ ] 3.3 Run the smallest relevant Go verification set
