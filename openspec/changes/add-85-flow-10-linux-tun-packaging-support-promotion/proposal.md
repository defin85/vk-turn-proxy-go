# Change: [85] Promote `linux_tun` packaging and support claims

## Why
After the Linux host boundary and Ubuntu ready-path work exist, the repository
still needs one separate change that says when `linux_tun` may be advertised as
supported in packaged builds and what install surface makes that claim honest.

Without that final step, the repository risks repeating the same confusion that
already had to be cleaned up for Windows: implementation details or lab success
getting mistaken for a shipped product support bit.

## Sequence
- Order: `85`
- Flow: `10`
- Depends on: `add-84-flow-10-linux-tun-ubuntu-ready-path`
- Completes flow: `10`

## What Changes
- Define the first repo-owned packaged/install surface for Linux `linux_tun` on
  the documented Ubuntu target.
- Define how the Linux package stages the desktop bundle, privileged helper,
  and privilege-mediation metadata together.
- Promote the runtime-execution and desktop-shell support claim for `linux_tun`
  only on the documented packaged Ubuntu target.
- Keep all other Linux targets fail-closed until they have their own packaged
  install surface and verified ready path.
- Define the runbook and verification bar required before the repository treats
  `linux_tun` as supported.

## Impact
- Affected specs: `native-build-workflows`, `runtime-execution-planning`,
  `desktop-gui-client`
- Affected code: future Linux packaging scripts, helper placement, desktop host
  capability advertisement, runtime docs and runbooks
