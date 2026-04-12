## 1. Contract
- [x] 1.1 Define the native build workflow contract for Go and Windows GUI artifacts
- [x] 1.2 Record the `E:\\Projects`-rooted Windows mirror requirement and artifact staging expectations

## 2. Implementation
- [x] 2.1 Add repo-owned build scripts for Go matrix builds from WSL and Windows GUI build orchestration
- [x] 2.2 Add a deterministic Windows-native mirror workflow rooted under `E:\\Projects`
- [x] 2.3 Pin the Flutter toolchain for `desktop/gui_shell` and add preflight validation for host-native builds
- [x] 2.4 Standardize artifact layout, including packaging `clientd.exe` next to the Windows GUI executable
- [x] 2.5 Wire the documented local and CI entrypoints to the new scripts and update the relevant docs

## 3. Verification
- [x] 3.1 Add the smallest practical script/build smoke coverage for the new workflow
- [x] 3.2 Verify the WSL Go build path still produces the required Go artifacts
- [x] 3.3 Verify the Windows GUI build path runs through the `E:\\Projects` mirror instead of UNC or temp execution
- [x] 3.4 Run strict OpenSpec validation and the smallest relevant local/CI reproduction set
