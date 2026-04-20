## Context
The mobile shell has already converged on several good building blocks:

- `Profiles` is a list-first workflow root.
- `Providers` is a list-first workflow root after change `34`.
- user templates are a separate reusable entity after change `35`.
- heavy catalog flows already use follow-on routes after change `38`.
- portable profile transfer already exists for mobile after change `31`.

What has not converged is the action model on top of those pieces.

Today the shell mixes at least four action placements for similar entity work:

- root buttons such as `Add profile` or `Add provider`
- row-tap selection
- editor footer actions
- disclosure-contained actions such as portable transfer

That fragmentation is especially visible in `Profiles`.
The list looks like the primary entity surface, but import/export and some
important secondary actions only appear after drilling into the editor.
`Providers` has the opposite bias: list/detail exists, but templates are still
partly framed as creation helpers rather than as first-class reusable records.

## Goals
- Make `Profiles` and `Providers` follow one visible action taxonomy.
- Expose the most important record actions from the workflow roots.
- Add first-class copy semantics for reusable entities.
- Keep editor surfaces focused on commit work rather than record management.
- Preserve the existing portable profile transfer model and provider/template
  data model.

## Non-Goals
- Add provider import/export; current portable transfer remains profile-only.
- Redesign provider settings semantics or template persistence.
- Change the owned-browser, resolution, or session workflows.
- Merge mobile and desktop UI contracts in the same change.

## Decisions

### Decision: Use one entity pattern: command bar -> list -> detail

Both `Profiles` and `Providers` will expose a root-level command surface above
their primary record list.
That command surface owns record-management actions.
Detail editors remain for inspecting and committing changes, not for hiding the
main action vocabulary.

Action placement rule:
- global entity actions live in the root command bar
- actions for the currently focused record live in a selection-aware root row
- detail surfaces do not add a second header-level record-action cluster

### Decision: Move profile transfer to the Profiles root

Portable profile transfer is already an explicit profile capability.
The correct place to discover it is the `Profiles` workflow root, not a draft
editor.

Root-level `Profiles` actions:

- `New`
- `Import`
- `Copy`
- `Export`
- `Delete`
- `Make current`

`Import` is a grouped action that can expose file, QR, and paste paths without
forcing the user into "new profile" first.
`Export` remains explicit and still opens the existing preview/confirmation
surface before copy/share/file actions.
Those focused-profile actions are surfaced through the root selection row rather
than a separate detail header cluster.

### Decision: Separate current-profile targeting from detail navigation

The current implementation couples "selected profile" with both editing context
and the `Home` target.
That coupling blocks clean action unification because row tap cannot both open
detail and preserve a stable current profile.

The shell should therefore distinguish:

- `currentProfileId`: the profile that `Home` uses for quick actions
- `focusedProfileId`: the profile currently open or highlighted for root/detail
  operations

Consequence:
- tapping a profile row opens or focuses detail
- making a profile current is explicit

State consequence:
- restored local shell state must preserve current-profile targeting separately
  from the last focused profile/editor context
- migrating from the old single-selection model must fail closed toward a sane
  default instead of silently guessing a destructive new target

### Decision: Promote templates to a first-class Providers surface

Templates are no longer just an optional branch of provider creation.
They are a reusable operator-owned asset and should live beside saved managed
providers as a peer surface inside `Providers`.

Root-level `Providers` surfaces:

- `Saved providers`
- `Templates`

Root-level `Saved providers` actions:

- `New provider`
- `Copy`
- `Use in profile`
- `Save as template`
- `Delete`

Root-level `Templates` actions:

- `Use template`
- `Copy`
- `Edit`
- `Delete`

The create-provider flow remains for choosing provider families or shipped
presets, but not for discovering the user's own reusable records.
Focused provider and template actions are surfaced through the same root
selection-row pattern instead of a second detail header cluster.

Consequence:
- shipped presets remain part of the create/bootstrap flow
- user-template management must not be duplicated between the create flow and
  the first-class template surface

### Decision: Keep editor footers commit-oriented

Editor footers stay reserved for commit actions.

Profile editor footer:
- `Save`
- `Start` or `Resolve`

Provider/template editor footer:
- `Save`
- template- or provider-specific commit action only if it is part of the
  current edit flow

Secondary entity actions such as copy, export, delete, or save-as-template move
to the root or surrounding detail command surface.

## Migration Map

| Entity | Current placement | Target placement |
| --- | --- | --- |
| Profile import | Profile editor disclosure | Profiles root command bar |
| Profile export | Profile editor disclosure | Profiles root command bar |
| Profile delete | Profile editor footer overflow | Profiles root/detail action surface |
| Profile copy | Missing | Profiles root/detail action surface |
| Provider save as template | Provider editor footer | Providers root/detail action surface |
| Provider copy | Missing | Providers root/detail action surface |
| Template copy | Missing | Templates root/detail action surface |
| Template discovery | Create-provider flow | First-class Providers surface |

## Risks / Trade-offs
- Splitting current-profile targeting from detail focus adds controller state and
  selection logic.
- Persisted-state migration from one profile-selection field to two related
  fields needs explicit restore rules or the shell will reopen in confusing
  states after upgrade.
- If root command bars are overbuilt, the shell could regress into a toolbar
  wall instead of a clearer entity workspace.
- Keeping delete out of the footer means destructive flows need careful
  placement and confirmation so they stay discoverable without competing with
  commit actions.
- If template promotion is implemented partially, operators may end up with two
  different places to manage templates, which is worse than the current state.
