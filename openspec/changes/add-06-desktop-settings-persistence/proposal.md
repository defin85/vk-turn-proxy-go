# Change: [06] Persist desktop GUI shell settings

## Why
The desktop GUI currently loses saved profiles and in-progress form state whenever the GUI or `clientd` restarts.
That makes the shell cumbersome for repeated testing and normal operator use.

## Sequence
- Order: `06`
- Depends on: `add-02-desktop-gui-shell`
- Unblocks: repeated desktop-shell validation and packaging work

## What Changes
- Persist saved desktop GUI profiles locally across shell restarts.
- Persist the selected profile and current unsaved draft across shell restarts.
- Rehydrate persisted profiles back into the local control-plane host after the GUI reconnects to a compatible host.

## Impact
- Affected specs: `desktop-gui-client`
- Affected code: `desktop/gui_shell`, desktop-shell docs
