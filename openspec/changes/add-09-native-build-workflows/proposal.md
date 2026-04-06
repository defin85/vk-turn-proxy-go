# Change: [09] Add reproducible native build workflows

## Why
As of April 6, 2026, the repository has a deterministic Go build path through `go test ./...` and `go build ./...`, but it does not have a reproducible local build workflow for host-bound binaries such as the Windows Flutter GUI.

The current Windows GUI build path is ad-hoc:
- Windows Flutter requires a Windows-native toolchain and does not build reliably from a WSL UNC working directory.
- the local Windows Flutter installation is already version-skewed from the Flutter/Dart version required by `desktop/gui_shell`
- manual temp copies or one-off path experiments are too fragile for repeatable agent-driven work

The project needs an explicit, reproducible build workflow so agents and operators can build the supported binaries without guessing where the source tree should live, which host should execute the build, or how artifacts should be staged.

## What Changes
- Add a new build-workflow capability that defines target-native local and CI entrypoints for supported binaries.
- Define a persistent Windows-native project mirror rooted under `E:\\Projects` for host-bound Windows GUI builds instead of temp copies or direct `\\\\wsl.localhost\\...` execution.
- Pin and preflight-check the Flutter toolchain used by `desktop/gui_shell` so incompatible Windows SDK versions fail closed before the build starts.
- Define deterministic artifact staging, including packaging `clientd.exe` next to the Windows GUI executable.
- Wire the documented local and CI build workflows to the same repository scripts instead of separate ad-hoc commands.

## Impact
- Affected specs: `native-build-workflows`
- Affected code: `Makefile`, future `scripts/`, `.github/workflows/ci.yml`, `desktop/gui_shell`, packaging docs, build environment docs
