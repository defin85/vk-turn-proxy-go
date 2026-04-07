# Change: [11] Add canonical build versioning and GUI surfacing

## Why
The repository currently exposes only one explicit version in the local control plane: `clientcontrol.ContractVersion`, which is a compatibility gate for the API contract.

That is not enough for operators or support:
- it does not tell the user which GUI build is running
- it does not tell the GUI which `clientd` build it is connected to
- it does not distinguish protocol compatibility from product/build identity
- it does not give the future Android/mobile path a reusable versioning contract

The result is avoidable confusion when staging or debugging builds, especially when multiple Windows bundles or sidecar versions exist at the same time.

## What Changes
- Add one canonical product/build versioning model for supported artifacts instead of overloading control-plane contract version negotiation.
- Define a repo-managed structured manifest with build number as the canonical version source, plus build metadata stamping for Go binaries and Flutter GUI artifacts.
- Extend the local control plane so host build identity is exposed separately from protocol compatibility version.
- Require the desktop GUI to show both its own build version and the connected host build version, with clear separation from contract version.
- Include build identity in diagnostics export from the first implementation slice so support bundles carry the same version context as the GUI.
- Keep the same versioning model reusable for the future Flutter mobile shell without assuming the desktop sidecar architecture on Android.

## Impact
- Affected specs: `build-versioning` (new)
- Affected code: `scripts/build-go-matrix.sh`, `scripts/build-windows-gui-from-wsl.sh`, `scripts/build-gui-windows.ps1`, `cmd/clientd`, `pkg/clientcontrol`, `desktop/gui_shell`, diagnostics export paths, version/build metadata helpers, docs
