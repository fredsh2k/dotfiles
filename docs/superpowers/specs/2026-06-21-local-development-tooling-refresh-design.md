---
title: Local Development Tooling Refresh
date: 2026-06-21
---

# Local Development Tooling Refresh

## Goal

Refresh the local opencode, dotfiles, and superpowers development setup so day-to-day agent work uses the intended local tools, current configuration, and verified skill/plugin wiring.

## Scope

- Dotfiles: update local opencode configuration, shell helpers, personal agent instructions, and tooling aliases only where they are stale or incorrect.
- Superpowers: verify local plugin registration, skill discovery, bootstrap injection, and lightweight tests. Avoid upstream-style skill rewrites unless a concrete local breakage requires a focused fix.
- opencode source: inspect the local checkout/build path and update dotfile helpers when they point at stale artifacts. Avoid modifying in-progress source files unless required for local tooling to work.
- Verification: validate edited config and run the smallest useful checks for opencode/superpowers behavior.

## Safety Rules

- Preserve current staged and unstaged work in both `~/Code/Personal/dotfiles` and `~/Code/Personal/opencode`.
- Stage and commit only intentional paths.
- Do not use destructive git commands.
- Do not push unless explicitly approved for the exact commit being pushed.
- Report any manual restart or TUI validation needed after config changes.

## Success Criteria

- `~/.config/opencode/opencode.json` remains schema-compatible and reflects the desired local MCP/plugin/tooling setup.
- Shell helpers in `.zshrc` launch the intended installed or local opencode binary without reviving stale session state unexpectedly.
- Personal instructions accurately describe the current local opencode workflow.
- Superpowers skills are discoverable through opencode and the bootstrap remains injected once per session.
- Verification results and any residual manual steps are documented in the final handoff.

## Open Questions

- Whether the final refreshed dotfiles state should include committing the already staged superpowers import and unrelated editor/shell changes.
- Whether the local compiled opencode worktree path in `.zshrc` is still the preferred fast path or should be replaced by a reproducible build/update command.
