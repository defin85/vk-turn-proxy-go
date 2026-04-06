# Build Workflows

Use repo-owned scripts for reproducible local and CI builds instead of ad-hoc commands.

## Go artifacts from WSL

Build the default Go matrix from the canonical WSL checkout:

```bash
./scripts/build-go-matrix.sh
```

Build a narrower target set when needed:

```bash
./scripts/build-go-matrix.sh windows/amd64
```

Artifacts are staged under `dist/go/<goos>-<goarch>/`.
The default matrix currently includes:
- `linux/amd64`
- `windows/amd64`

## Windows GUI from WSL

Windows Flutter desktop builds are host-bound and must run through a Windows-native toolchain.
The repository standardizes that path through a persistent mirror at `E:\Projects\vk-turn-proxy-go`.

Prerequisites:
- WSL checkout remains the canonical source tree.
- `E:\Projects` is mounted in WSL at `/mnt/e/Projects`.
- Windows has a compatible Flutter SDK version matching `desktop/gui_shell/.flutter-version`.
- Windows has the Visual Studio C++ desktop workload and Windows SDK required by `flutter build windows`.

Run the repo-owned wrapper from WSL:

```bash
./scripts/build-windows-gui-from-wsl.sh
```

That workflow:
1. cross-builds the required Windows Go sidecar artifacts from WSL
2. synchronizes the repository into `E:\Projects\vk-turn-proxy-go`
3. runs the native Windows GUI build from that mirrored path
4. stages the packaged bundle under `dist/windows-gui/`

The Windows GUI package includes a sibling `clientd.exe` next to `gui_shell.exe`.

## Native Windows GUI build

When the mirror already exists at `E:\Projects\vk-turn-proxy-go`, run the Windows-native build script directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\build-gui-windows.ps1
```

The script fails closed if:
- it is run from a UNC path
- the pinned Flutter version is missing or mismatched
- `flutter doctor -v` does not confirm the required Windows desktop toolchain
- `dist\go\windows-amd64\clientd.exe` is missing

## Local entrypoints

From the repository root:

```bash
make build-go
make build-gui-windows
```

`make ci` remains the fast Go-only smoke path.

## CI

The repository uses the same repo-owned scripts in CI:
- Ubuntu runners use the Go build/test entrypoints
- Windows runners build the GUI through `scripts/build-gui-windows.ps1`
