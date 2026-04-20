---
name: cross-agent-instructions-file
description: Wire a single source-of-truth instructions file (user prefs, conventions, never-do rules) so multiple coding/CLI agents — Hermes, OpenCode, Claude Code, Cursor — all pick it up automatically via symlinks. Avoids drift between per-agent rule files.
---

# Single-Source-of-Truth Cross-Agent Instructions File

When a user works with multiple agents (Hermes + OpenCode + Claude Code + Cursor + …), they typically want **one** file of personal rules ("use ripgrep not grep", "never push without approval", "use rip not rm") that **every** agent reads. Per-agent rule files inevitably drift.

## The wiring pattern

1. **Canonical file** lives in tracked dotfiles. Recommended path:
   `~/Code/Personal/dotfiles/.agents/instructions/<username>.instructions.md`
2. **Symlink** the canonical file into each agent's discovery path (see table below).

```zsh
TARGET="$HOME/Code/Personal/dotfiles/.agents/instructions/<username>.instructions.md"
ln -sfn "$TARGET" "$HOME/AGENTS.md"                   # Hermes (cwd-based)
ln -sfn "$TARGET" "$HOME/.config/opencode/AGENTS.md"  # OpenCode global
ln -sfn "$TARGET" "$HOME/CLAUDE.md"                   # Claude Code (if used)
```

`ln -sfn` = force, no-dereference — safely overwrites a stale symlink without clobbering a real file at that path. Verify first with `ls -la <link>`.

## Where each agent looks (discovery rules)

| Agent | Discovery path | Recursive? | Notes |
|---|---|---|---|
| Hermes | `AGENTS.md` / `agents.md` in **cwd** (top-level only) | No (subdirs progressively as agent navigates) | Also reads `.hermes.md`/`HERMES.md` (walks to git root), `.cursorrules`, `CLAUDE.md`. Source: `~/.hermes/hermes-agent/agent/prompt_builder.py` and `agent/subdirectory_hints.py`. Default cwd at launch is `$HOME` → symlink at `$HOME/AGENTS.md` is correct. |
| OpenCode | global config dir, then project root | Project-level too | Loads global first, project overrides. |
| Claude Code | user-level `CLAUDE.md`, then project `CLAUDE.md` | Walks up tree | Project file takes precedence. |
| Cursor | `.cursorrules` at project root | No | Per-project only. Global needs a symlink trick. |

## Pitfalls

- **Hermes does NOT auto-load OpenCode's config dir** — it scans cwd, not OpenCode's discovery path. You must create a separate symlink in `$HOME` (or wherever the user launches Hermes from).
- **Don't confuse the canonical file with the symlinks.** Edits go to the canonical path (so they're tracked in dotfiles git). Symlinks are write-through but git-tracking lives at the target.
- **Symlinks in `$HOME` are untracked by default** — they're not tracked dotfiles. If the user wants new machines bootstrapped automatically, add the `ln -sfn` line to `install.sh` / `mac-install.sh`.
- **Format compatibility**: all four agents accept plain markdown. The optional YAML frontmatter (`applyTo: "**/*"`) is OpenCode-specific and is harmless to other readers.
- **Per-agent overrides**: if one agent needs different behavior, do NOT fork the canonical file. Add an `## Agent: opencode` / `## Agent: hermes` section inside the canonical file and let each agent self-filter, OR keep a small per-agent supplement file alongside.

## Verification

```zsh
for link in $HOME/AGENTS.md $HOME/.config/opencode/AGENTS.md $HOME/CLAUDE.md; do
  [ -L "$link" ] && printf "%-40s -> %s\n" "$link" "$(readlink "$link")"
done
# All present links should resolve to the same canonical path.
```

Then start a fresh Hermes session and ask "what rules do you follow?" — it should recite the canonical file's contents.

## When the user says "you broke a rule that's in my instructions"

Two failure modes — diagnose which:
1. **Wiring missing**: agent never loaded the file. Check the symlink exists at the agent's discovery path. Fix with `ln -sfn`.
2. **Rule missing from canonical file**: the user *thinks* it's in there but it isn't. Read the canonical file, confirm, then add the rule (don't just promise to remember it — promises don't survive context compaction). Commit to dotfiles.

Source-tested experientially in Hermes (Apr 2026) — caught a "never push without approval" rule that the user thought was in the file but wasn't, and a missing top-level symlink that meant Hermes never read the file at all.
