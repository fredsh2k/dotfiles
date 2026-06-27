---
name: updating-local-dev-tools
description: Use when updating local developer tools, agent CLIs, Homebrew packages, Ruby/rbenv tooling, Go-installed binaries, Rust toolchains, Bun/npm/pnpm, opencode, copilot, or herdr on this machine.
---

# Updating Local Dev Tools

## Overview

Keep local developer tools current through the native updater for each tool. Prefer curated updates over blanket upgrades, and verify the active binary on `PATH` after updating.

## When to Use

- The user asks to update local tools, CLIs, agents, opencode, copilot, herdr, Ruby, Go, Rust, Bun, npm, pnpm, Homebrew tools, or Kubernetes tooling.
- A tool reports it is outdated, shadowed, or running from an unexpected path.
- You need to refresh dotfiles-managed update workflows.

## Quick Commands

| Goal | Command |
| --- | --- |
| Check status only | `devtools-update --check` |
| Curated update | `devtools-update` |
| Broad Homebrew/cask update | `devtools-update --greedy` |

## Update Order

1. Use self-updaters first: `herdr update`, `opencode upgrade`, `copilot update`, `bun upgrade`.
2. Update package managers and globals: `npm update -g`, `corepack install -g pnpm@latest yarn@latest`.
3. Update language toolchains: `rustup update stable`, RubyGems/rbenv/ruby-build, Go binaries in `~/go/bin`.
4. Update Homebrew with a curated CLI list by default. Use `--greedy` only when the user explicitly wants broad cask/formula upgrades.
5. Verify with `devtools-update --check` or a targeted version sweep.

## Local Notes

- `opencode-start` runs official `opencode web` on a stable port with `--hostname 0.0.0.0 --mdns` for Tailscale/phone access.
- `opencode-attach` attaches the current directory to the shared web server.
- `copilot` should resolve to the official package, not the old dotfiles local wrapper.
- `herdr` has its own updater; do not replace it via ad hoc downloads unless `herdr update` fails.
- Some tools reject `--version`; use their native `version` command or the `devtools-update --check` helper.

## Common Mistakes

- Do not use `brew upgrade --greedy` by default; it upgrades GUI apps and casks too.
- Do not keep local wrapper scripts when the official CLI supports the desired workflow.
- Do not assume the upgraded Homebrew binary is active; check `command -v`, because `~/.local/bin` and shims may shadow Homebrew.
- Do not let one failed Go/Ruby tool update abort the whole run; continue and report failures.
