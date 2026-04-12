## Context
The repository currently treats builds as a Go-only concern:
- [Makefile](/home/egor/code/vk-turn-proxy-go/Makefile) only exposes `go test ./...` and `go build ./...`
- GitHub Actions only runs the same Go pair on `ubuntu-latest`
- `desktop/gui_shell` documents Linux-local Flutter workflows but not a reproducible Windows build path

That is enough for Go binaries, but not for host-bound GUI artifacts.
Flutter Windows builds require a Windows-native toolchain.
Running Windows Flutter directly against a WSL-hosted checkout is unreliable because the Windows Flutter launcher eventually goes through `cmd.exe`, which does not preserve a UNC current working directory such as `\\\\wsl.localhost\\...`.

The result is exactly the kind of workflow drift we want to eliminate:
- WSL remains the best place for the canonical Go workflow
- Windows remains mandatory for `flutter build windows`
- local toolchains can silently drift unless the repository owns version checks
- manual temp copies are not reproducible enough for agent automation

## Goals
- Give the repository one documented, target-native build workflow per supported artifact class.
- Keep Go builds agent-friendly from WSL, including Windows `.exe` sidecars produced by cross-compilation.
- Make Windows GUI builds reproducible from a persistent Windows-native mirror rooted under `E:\\Projects`.
- Ensure local and CI workflows call the same repo-owned scripts and produce predictable artifact locations.
- Fail closed when a host-native toolchain is missing or incompatible.

## Non-Goals
- Replace Flutter with another desktop UI stack.
- Require day-to-day Go development to move from WSL into Windows.
- Claim that macOS GUI artifacts can be built locally from WSL.
- Add installer signing, MSIX packaging, or auto-update distribution in this change.

## Decisions
### Decision: Build natively per target

Go binaries remain buildable from WSL, including Windows-target `.exe` artifacts through standard Go cross-compilation.
Host-bound GUI targets build on the host that owns the native toolchain.
For this repository, that means Windows GUI builds run on Windows, even when they are orchestrated from WSL.

### Decision: Use a persistent Windows-native mirror rooted under `E:\\Projects`

The Windows build workflow should not depend on temp directories or direct UNC execution from the WSL checkout.
Instead, the repository owns a persistent Windows-native mirror rooted under `E:\\Projects`, with a documented project subdirectory such as `E:\\Projects\\vk-turn-proxy-go`.

The WSL wrapper is responsible for synchronizing source into that mirror deterministically before invoking Windows-native build steps.

### Decision: Pin Flutter through repo-managed tooling

The desktop GUI build must use a repo-managed Flutter version instead of whichever `flutter` happens to be first on `PATH`.
The implementation may use FVM or an equivalent checked-in wrapper, but the contract is that local and CI builds resolve the same pinned Flutter SDK version and fail early on mismatch.

### Decision: Package the Windows GUI with a sibling `clientd.exe`

Packaged Windows GUI artifacts should not depend on repo-local `go run` fallback behavior.
The Windows GUI distribution stages a compatible `clientd.exe` next to the GUI executable, matching the existing sidecar-discovery contract.

### Decision: Standardize artifact and script entrypoints

The repository should expose stable scripts for:
- Go matrix builds from WSL
- Windows GUI build orchestration from WSL
- Windows-native build execution
- build-environment doctor checks

CI should call those same scripts rather than open-coding a second workflow.

## Risks / Trade-offs
- Maintaining a Windows-native mirror under `E:\\Projects` introduces one more synced workspace.
  Mitigation: keep the mirror persistent, deterministic, and repo-owned instead of relying on ad-hoc copies.
- Pinned Flutter tooling adds setup overhead for developers who only touch Go.
  Mitigation: scope Flutter checks to GUI workflows and keep Go entrypoints independent.
- Windows GUI builds may still fail for machine-specific Visual Studio or SDK issues.
  Mitigation: add an explicit doctor/bootstrap step that checks prerequisites before the build starts.
- CI complexity increases once Windows GUI builds become first-class.
  Mitigation: reuse the same scripts in local and CI flows so only one build contract exists.

## Validation Plan
- Strict OpenSpec validation for the new change.
- Script-level smoke coverage for sync and doctor behavior where practical.
- Local verification that WSL Go workflows still produce Linux and Windows-target artifacts.
- Local verification that the WSL wrapper can drive a Windows GUI build through the `E:\\Projects` mirror path.
- CI coverage that exercises the repo-owned build scripts on both Ubuntu and Windows runners.
