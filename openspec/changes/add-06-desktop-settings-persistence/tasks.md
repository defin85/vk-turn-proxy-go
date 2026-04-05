## 1. Desktop shell persistence contract
- [x] 1.1 Define the persisted desktop shell state for saved profiles, selected profile, and draft values
- [x] 1.2 Define how persisted shell state is restored into the local host after reconnect

## 2. Implementation
- [x] 2.1 Add a file-backed desktop shell state store
- [x] 2.2 Restore persisted state during desktop shell startup and reconnect
- [x] 2.3 Persist profile and draft mutations without blocking the control-plane workflow

## 3. Verification
- [x] 3.1 Add Flutter tests for persistence save/restore behavior
- [x] 3.2 Run `cd desktop/gui_shell && flutter test`
- [x] 3.3 Run `openspec validate add-06-desktop-settings-persistence --strict --no-interactive`
