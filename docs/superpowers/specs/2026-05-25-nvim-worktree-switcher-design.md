# Neovim Worktree Switcher Design

## Goal

Add a LazyVim/Snacks-native picker that switches the current tab to another Git worktree for the current repository.

## Current Context

- Neovim config lives under `.config/nvim` in the dotfiles repo.
- LazyVim loads custom config from `lua/config/keymaps.lua` and `lua/plugins/*.lua`.
- `lua/config/keymaps.lua` already uses `Snacks.picker` for repo and tab selection.
- The preferred workflow is to replace the current tab cwd instead of opening a new tab.

## Approach

Implement a custom Snacks picker in `lua/config/keymaps.lua`.

The picker will:

- Use `git rev-parse --show-toplevel` to find the current repository.
- Use `git worktree list --porcelain` from that repository to discover linked worktrees.
- Show each worktree with branch name when available and path as fallback.
- On selection, run `:tcd <worktree-path>` to replace the current tab cwd.
- Set the current tab `name` variable to the selected branch or directory name.
- Open the selected worktree README if present; otherwise keep the current buffer.
- Refresh Snacks explorer with the selected cwd.
- Safely run `:LspRestart` if available.

## Keymap

Use `<leader><tab>w` with description `Switch Worktree`.

This matches the existing repo/tab namespace:

- `<leader><tab>n`: new repo tab.
- `<leader><tab>f`: find tab.
- `<leader><tab>w`: switch current tab to worktree.

## Dependencies

- Required external tool: `git`.
- No new Neovim plugin is required.
- No Homebrew package is required for the initial implementation.

## Error Handling

- If the current buffer is not inside a Git repo, show a warning notification.
- If `git worktree list` fails, show a warning notification.
- If no linked worktrees exist, show a warning notification.
- If `Snacks.explorer` or `LspRestart` is unavailable, fail softly.

## Testing

- Run a Lua syntax/load check if available.
- Manually open Neovim in a repository with linked worktrees.
- Use `<leader><tab>w` and verify the tab cwd changes.
- Verify files/explorer reflect the selected worktree.
- Verify LSP restarts or at least does not error.

## Scope

This does not create or delete worktrees. It only switches to existing worktrees.
