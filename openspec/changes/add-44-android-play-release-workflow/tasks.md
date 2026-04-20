## 1. Release contract
- [ ] 1.1 Define the Google Play-target Android release artifact contract,
      including the staged artifact type, signing prerequisites, and explicit
      non-goals for operator-owned Play Console work.
- [ ] 1.2 Define the boundary between store-target Android packages and the
      existing debug-only mobile workflow so local workstation assets do not
      silently cross into the release lane.

## 2. Build workflow and packaging
- [ ] 2.1 Add a repo-owned Android release build entrypoint from WSL that
      stages a Play-upload artifact from the canonical version and publish
      identity sources instead of only building a debug APK.
- [ ] 2.2 Replace the current debug-signing fallback with explicit upload-key
      signing configuration that fails closed when the keystore path, alias, or
      passwords are missing or invalid.
- [ ] 2.3 Add release preflight checks for Play-target packaging, including the
      repo-managed Android target floor and checks that reject development-only
      assets in the release package.

## 3. Docs and operator handoff
- [ ] 3.1 Document the release signing inputs, repo-owned Android release
      entrypoint, staged artifacts, and local verification path.
- [ ] 3.2 Document the operator-owned Google Play handoff, including Play App
      Signing enrollment, release-track upload, store listing/contact details,
      and app-content declarations, without claiming that the repo-owned
      scripts publish directly to the store.

## 4. Verification
- [ ] 4.1 Add or update targeted checks that prove the Android release
      packaging lane produces the intended signed upload artifact and excludes
      repo-local debug assets fail-closed.
- [ ] 4.2 Run `openspec validate add-44-android-play-release-workflow --strict --no-interactive`.
