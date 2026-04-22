---
name: vk-turn-desktop-shell
description: Use for desktop GUI shell work in vk-turn-proxy-go. Applies product-specific rules for fail-closed host state, diagnostics and live-work placement, profile/provider workflows, pane navigation, and shell hierarchy around the local control-plane contract.
---

# Vk Turn Desktop Shell

## Overview

This is a product-specific adapter skill. Use it for `vk-turn-proxy-go`
desktop shell work, not as a general Flutter desktop guideline.

## Use This Skill When

- editing `desktop/gui_shell`
- reviewing shell hierarchy against OpenSpec
- touching diagnostics, live work, provider workflow, or profile workflow UI
- changing shell bar, navigation rail/drawer, panes, or inspectors

## Product Rules

- fail-closed host and tunnel states must stay explicit
- diagnostics and live work stay secondary by default; if exposed as explicit
  support routes, they must not reclaim the routine main workflow
- common path should dominate: choose context, edit, resolve/start
- routine ready state should stay compact
- blocked or incompatible state must remain reachable without hidden navigation
- presets remain subordinate to managed-provider workflow

## State Model Expectations

- keep top-level section separate from entity selection
- keep inspector visibility separate from workflow section
- avoid overloading one enum to represent shell section, selection, and mode

## Review Standard

When auditing or changing this shell:

- confirm claims against code and OpenSpec
- preserve typed control-plane semantics
- avoid returning to a peer-card dashboard layout
- prefer pane-based workflow composition

## Read These References

- `references/product-rules.md`
  Read for compact product-specific shell rules.

- `references/repo-entrypoints.md`
  Read for the files and docs to open first in `vk-turn-proxy-go`.
