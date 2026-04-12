## Context
The current repository has two separate version-related realities:

- the local control plane has a compatibility version, currently `ContractVersion = "1"`
- the Flutter desktop app has its own package version in `desktop/gui_shell/pubspec.yaml`

Neither of those gives the full operational picture.
The GUI banner currently labels the host as `version 1`, but that value is the control-plane contract version, not the build that is actually running.
At the same time, Go binaries such as `clientd` do not expose a canonical product version or revision at all.

That gap already hurts desktop packaging and debugging, and it will become more expensive once a Flutter mobile shell exists and needs to share the same product identity while still targeting different runtime architectures.

## Goals
- Keep protocol compatibility versioning explicit and separate from build identity.
- Give every supported artifact one canonical product version and one build identity shape.
- Make the GUI show its own version and the connected host version without requiring terminal inspection.
- Keep development workflows such as `go run ./cmd/clientd` and `flutter run` usable, even when full release stamping is absent.
- Reuse the same model for the future Flutter mobile shell without assuming desktop-only packaging.

## Non-Goals
- Add auto-update channels, release feeds, installer signing, or store publication.
- Replace existing control-plane negotiation with semver range resolution.
- Guarantee that every non-repo build path carries perfect release metadata.
- Define Android store signing, bundle publishing, or device-specific distribution in this change.

## Decisions
### Decision: Separate contract version from product/build version

`clientcontrol.ContractVersion` remains the compatibility key for the local control plane.
It must not double as the human-facing product version.

The control plane instead exposes two separate concepts:
- `contract_version`: compatibility for negotiation
- `build`: human-facing product/build identity for the running host

### Decision: Use one repo-managed structured manifest as the canonical version source

The repository should own one canonical structured manifest that build scripts use for both Go binaries and Flutter artifacts.
The manifest must be script-readable and reusable by desktop and future mobile packaging.

The manifest carries, at minimum:
- product version
- build number
- optional channel or prerelease metadata if the repository later needs it

This manifest is the source of truth for human-facing version identity.
Derived build metadata such as revision, dirty state, and build timestamp may still be computed at build time.

### Decision: Stamp build metadata into both Go and Flutter artifacts

Supported build entrypoints should stamp at least:
- product version
- revision
- dirty/not-dirty state
- build timestamp
- artifact role or target where relevant

Go binaries should expose this through a shared runtime helper.
Flutter builds should expose the same product version and supplemental build identity to the GUI at runtime.

### Decision: Include build identity in diagnostics bundles from the first slice

Diagnostics export should include version context for support from the first implementation slice.

The diagnostics shape should carry enough metadata to answer:
- which GUI build produced the bundle
- which host build backed the session
- which contract version governed compatibility

This avoids a split-brain support workflow where the GUI banner shows useful version context but exported diagnostics do not.

### Decision: Keep dev-mode fallbacks explicit

Repo-owned build scripts provide the canonical stamped path, but local development flows must still surface something useful.

For Go binaries started through `go run` or plain `go build`, the runtime may fall back to available module/build info if explicit release stamps are absent.
For Flutter dev runs, the GUI may fall back to package metadata plus whatever supplemental build stamp is available.

### Decision: Surface both local GUI and remote host identity in the GUI

The GUI should show:
- its own app version/build identity
- the connected host version/build identity
- the control-plane contract version when that is relevant to compatibility

These values should be labeled distinctly so the operator can tell "which GUI am I running?" from "which host am I connected to?" and from "are they protocol-compatible?".

### Decision: Make host identity observable even when negotiation fails

The GUI should still be able to show host build identity when a host is present but incompatible.
That implies a read path for host build metadata that does not depend entirely on successful negotiate-as-compatible semantics.

## Alternatives Considered
### Overload the existing `version` field in `HostInfo`

Rejected.
That would continue to blur control-plane compatibility with product identity and keep the UI ambiguous.

### Keep versioning only in packaging metadata

Rejected.
That would help installers but not runtime support, GUI-to-host skew analysis, or control-plane diagnostics.

### Use separate unrelated version schemes for desktop and future mobile

Rejected.
The repository is already converging on Flutter shells across desktop and mobile, so versioning should be shared unless a future platform constraint proves otherwise.

## Risks / Trade-offs
- A repo-managed version source adds one more file or generation step to release workflows.
  Mitigation: keep the source simple and validate it in the repo-owned build scripts.
- Flutter package versioning and runtime build metadata can drift if only one is updated.
  Mitigation: build scripts must validate or generate the Flutter-facing values from the canonical version source.
- Development builds may not carry the same fidelity as release builds.
  Mitigation: explicitly label fallback metadata so operators can distinguish release-stamped builds from local dev runs.
- Exposing build revision in the GUI may surface noisy details for normal users.
  Mitigation: keep concise version labels in the primary banner and push lower-level metadata into secondary details or diagnostics surfaces.

## Migration Plan
1. Add the canonical structured version manifest and shared build metadata helpers.
2. Stamp Go and Flutter build outputs through the repo-owned build scripts.
3. Extend the control-plane host info shape with separate build identity fields.
4. Extend diagnostics export so GUI and host build identity are persisted with the session bundle.
5. Update the desktop GUI to surface local and host versions explicitly.
6. Reuse the same version source for future mobile packaging once the mobile shell exists.
