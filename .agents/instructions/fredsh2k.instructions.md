---
applyTo: "**/*"
---

Use zsh as the terminal shell.
Use code-insiders over code for VS Code.

IMPORTANT: Always use modern CLI tools instead of legacy ones.
ALWAYS use `rg` (ripgrep) instead of grep or built-in search tools
ALWAYS use `fd` instead of find or built-in glob tools
ALWAYS use `sd` instead of sed for find-and-replace
ALWAYS use `rip` instead of rm (safer, uses graveyard)

NEVER `git push` without my explicit approval. Stage and commit freely, but always pause and ask before pushing to any remote — including dotfiles, personal repos, and work repos. This applies to `git push`, `gh pr merge`, force-pushes, and anything else that mutates a remote.
When using git commit use simple one-liner messages prefixed with fix: or feat: or docs: etc.
When using git add use specific file paths, never use -A or --all or . (dot).
After creating new files, always `git add` them so they can be reviewed in LazyVim with `space g D` (Diffview). Untracked files don't appear in diffview.
When using git checkout use short branch names without my username or other prefixes.

When using gh cli use --no-pager or cat to avoid pager terminal buffers.
When creating PRs always create them as draft and use the PR template if available and mention part of issue number at the end of the PR description.
When creating issues, always make them as high level requirements, no need to deep dive into specific implementations.
Make sure to create sub-issues where appropriate for easier tracking using the gh graphql api.
When analyzing gh pr checks failures, always save the logs to a file and use ripgrep to search for relevant error messages instead of running gh pr checks repeatedly.
Do not reply to people comments on PRs.

Before cloning any repo, always check if it already exists under /Users/fsherman/Code/GitHub/ first.
When researching internal GitHub infrastructure, platforms, or services, read the thehub repo at `/Users/fsherman/Code/GitHub/thehub` for documentation.

Dotfiles live as a regular git clone at `~/Code/Personal/dotfiles`, with tracked files symlinked into `$HOME`.
Use `git -C ~/Code/Personal/dotfiles ...` (or the `dot` alias) for all dotfile git operations. Edit files via the repo path so changes flow through the symlinks.
Remote: https://github.com/fredsh2k/dotfiles.git (do NOT push without approval — see git-push rule above).

`~/.hermes/skills/` is a symlink to `~/Code/Personal/dotfiles/.hermes/skills/` — every skill is tracked. Any `skill_manage(action='patch')` writes appear in `git diff` for review. Use `git log --oneline .hermes/skills/<path>` to see history; delete unused skills with `rip ~/.hermes/skills/<cat>/<name>/` then `git -C ~/Code/Personal/dotfiles add -A .hermes/skills`.

## Dev environment

- **Terminal**: Ghostty (supports Kitty graphics protocol for inline images; `copy-on-select = clipboard` configured)
- **Editor**: LazyVim (Neovim). Stay close to defaults, minimal custom plugins. Config at `~/.config/nvim/`.
- **AI**: OpenCode runs in a separate terminal pane, not embedded in Neovim.
- **Shell**: zsh + oh-my-zsh + spaceship prompt + zsh-vi-mode. Config at `~/.zshrc`.
- **Cheatsheets**: `/Users/fsherman/Code/Personal/cheatsheets/` (local git, no remote)

