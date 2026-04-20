---
name: dotfiles-management
description: Manage user dotfiles (.zshrc, .config/, etc.) with git. Covers bare-repo, symlink-farm, GNU Stow, and chezmoi approaches, plus the worktree trick that combines bare-repo's transparency with a browseable repo dir for editor/agent ergonomics.
---

# Dotfiles Management

Help users track home-directory config files in git. **Always discover their existing setup before recommending migration** — most users with a working dotfiles repo do not benefit from switching tools.

## Discovery (do this FIRST, every time)

Before suggesting any approach, inspect what's already there:

```zsh
# Bare repo? (most common power-user setup)
ls -la ~/.dotfiles.git ~/.dotfiles 2>/dev/null
grep -E 'dotfiles|--git-dir' ~/.zshrc ~/.bashrc 2>/dev/null

# Symlinks pointing into a repo?
for f in ~/.zshrc ~/.config/nvim ~/.config/ghostty; do
  [ -L "$f" ] && printf "%-30s -> %s\n" "$f" "$(readlink "$f")"
done

# chezmoi?
command -v chezmoi && chezmoi source-path 2>/dev/null

# GNU Stow packages?
ls ~/Code/Personal/dotfiles ~/dotfiles 2>/dev/null

# If bare repo found, inspect:
DOT="git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME"
$DOT remote -v
$DOT ls-files | head
$DOT ls-files | wc -l
```

If they have a working setup with a remote and bootstrap script (`install.sh`/`mac-install.sh`), **do not migrate without strong justification**. Suggest worktree augmentation instead.

## Approach comparison

| Approach | Pros | Cons | Best for |
|---|---|---|---|
| **Bare repo** (`~/.dotfiles.git`, worktree=`$HOME`) | Files at original paths, no symlinks, single command bootstrap on new machines, `dot status` from anywhere | No "project root" for editors, force-add gymnastics for nested ignored trees (e.g. `~/.hermes/skills/`) | Power users, single-machine, polished setups |
| **Symlink farm** (repo at `~/Code/.../dotfiles`, `ln -s` back to `$HOME`) | Browseable repo dir, editor/agent picker shows scoped files, no extra deps | Some apps misbehave with symlinked configs, manual `mv` + `ln -s` per file, breaks if Hermes/agent overwrites the symlink itself | Users who explicitly want a "project" feel and are willing to manage links |
| **GNU Stow** | Pure symlinks with directory-folding bookkeeping, per-package install on new machines | Extra dep (`brew install stow`), imposes package-dir convention, marginal win over plain `ln -s` for <20 paths | Multi-machine, many packages |
| **chezmoi** | Templating across machines, secrets integration (1Password/age), `chezmoi diff/apply` workflow | Copies (not symlinks) by default — agents editing live files need `chezmoi re-add`, heavier mental model | Multi-machine fleets, secrets-heavy setups |

**Rule of thumb**: For a single-machine setup with <30 dotfile paths, **plain `ln -s` + Makefile** beats Stow. Don't add deps for bookkeeping you can do in 10 lines of bash.

## DO NOT use git worktrees as a "unified view" hack

A tempting-but-wrong idea: `git --git-dir=$HOME/.dotfiles.git worktree add ~/Code/Personal/dotfiles main` to get a "browseable copy" alongside the live `$HOME` files. **This does not work the way it sounds.**

Worktrees are **separate physical working copies** sharing only `.git`. Editing `~/Code/Personal/dotfiles/.zshrc` does NOT update `~/.zshrc` and vice versa — the user has two independent files that drift unless they `git commit` + `git checkout` to sync. This defeats the entire point.

If the user wants both a live config and a browseable repo dir from the same source of truth, the only options are:
- **Symlinks** (one canonical file in the repo dir, `$HOME` paths are symlinks pointing at it)
- **chezmoi** with `chezmoi apply` after every edit

Tested experientially in Apr 2026 — recanted the worktree recommendation mid-session after discovering this. Don't repeat the mistake.

## Selectively tracking files inside an ignored tree (bare repo)

Common case: ignore all of `~/.hermes/` (auth tokens, SQLite, bundled stuff) but track one custom skill folder.

```zsh
# 1. Add blanket ignore to ~/.dotfiles.git/info/exclude
cat >> ~/.dotfiles.git/info/exclude <<'EOF'

# Hermes — ignore everything except explicitly force-added custom skills
.hermes/
EOF

# 2. Force-add specific paths (overrides ignore)
DOT="git --git-dir=$HOME/.dotfiles.git --work-tree=$HOME"
$DOT add -f ~/.hermes/skills/<category>/<skill-name>/
$DOT commit -m "track custom skill <name>"
```

`-f` is required and safe — it only adds the explicit path, doesn't override the ignore for siblings. Verify with `$DOT status --ignored -s -- ~/.hermes/`.

## Tracking an entire agent-managed directory (auditing self-modifications)

When an agent (Hermes, OpenCode, Claude Code) writes into its own state dir — e.g. `skill_manage(action='patch')` editing `~/.hermes/skills/<x>/SKILL.md` — those writes are normally invisible: no git, no diff, no audit trail. Pattern to make every write visible:

1. Move the entire dir into the dotfiles repo
2. Replace the original path with a **directory symlink** pointing into the repo
3. Now every agent write lands inside the repo and shows up in `dot status` / `dot diff`

```zsh
SRC="$HOME/.hermes/skills"
DST="$HOME/Code/Personal/dotfiles/.hermes/skills"

# Pre-flight: clean garbage that shouldn't be tracked
fd -H -t d __pycache__ "$SRC" -x rm -rf {}
fd -H -t f -e pyc . "$SRC" -x rm {}

# Resolve any existing symlinks inside SRC that point INTO DST (otherwise rsync copies the symlink itself)
# These exist if you previously file-level-tracked individual files from this tree.
for link in $(fd -t l . "$SRC"); do
  target=$(readlink "$link")
  if [[ "$target" == "$DST"/* ]]; then
    rm "$link" && cp "$target" "$link"
  fi
done

# Merge SRC into DST, preserving any files DST already had
rsync -a --ignore-existing "$SRC/" "$DST/"

# Verify zero diffs
diff -rq "$SRC" "$DST"   # must be empty

# Swap: backup original, replace with symlink
mv "$SRC" "$SRC.pre-symlink-bak"
ln -s "$DST" "$SRC"

# Add a .gitignore inside the now-tracked dir for transient state
cat > "$DST/.gitignore" <<'EOF'
__pycache__/
*.pyc
.DS_Store
node_modules/
EOF

cd ~/Code/Personal/dotfiles
git add .hermes/skills && git commit -m "feat: track all <agent> skills"
```

**Why directory symlink (not file-level)**: file-level tracking misses any *new* file the agent creates, since the new file lives outside the repo. A directory symlink captures all future writes automatically.

**Cost**: bundled/upstream files get tracked too. For Hermes skills this was ~9.8 MB / 434 mostly-text files — acceptable. If the dir is huge or contains binaries/caches, prefer the selective force-add pattern instead.

**Workflow unlocked**:
- After any session: `dot status` shows what the agent self-modified
- History per-skill: `dot log --oneline -- .hermes/skills/<cat>/<name>/`
- Find unused skills: `dot log --since="3 months ago" --name-only -- .hermes/skills/ | sort -u` — anything missing hasn't been touched
- Bootstrap scripts using file-level `git ls-files | xargs ln -s` still work on fresh machines (they create individual file symlinks instead of a dir symlink — equivalent end state for read/write).

Tested in Hermes (Apr 2026).

## Plain symlink migration recipe (when truly warranted)

```zsh
mkdir -p ~/Code/Personal/dotfiles && cd $_
git init -b main

for pair in \
  "$HOME/.zshrc:.zshrc" \
  "$HOME/.config/nvim:nvim" \
  "$HOME/.config/ghostty:ghostty"
do
  src="${pair%%:*}"
  dst="${pair##*:}"
  mv "$src" "$dst"
  ln -s "$PWD/$dst" "$src"
done

git add -A && git commit -m "initial import"
```

Use `ln -sfn` (force, no-deref) in install scripts to overwrite stale symlinks safely without nuking real files.

## Pitfalls

- **Don't migrate working setups without explicit user request and clear justification.** A bare repo with a remote + bootstrap script + 27 tracked files is not a problem to solve.
- **Codespaces dotfiles** require a specific layout (`install.sh` at root, files at relative paths matching `$HOME`). Bare repo + symlink approaches both work; chezmoi requires extra config.
- **macOS `~/.zshrc`** may be on agent protected-files lists. The symlink target (e.g. `~/Code/Personal/dotfiles/.zshrc`) is NOT protected by default — agents can edit it freely, which may or may not be desired. Consider adding the target to the protected list if you want to keep manual gating.
- **Bundled vs custom files** in agent-managed dirs (`~/.hermes/skills/`, `~/.config/nvim/lazy-lock.json`) — only track the custom ones; bundled state regenerates and creates churn.
- **`~/.Trash/` permission warnings** in `dot status`: harmless, suppress with `dot config status.showUntrackedFiles no`.
- **`~/.dotfiles.git/info/exclude`** is per-repo and not committed. To share ignore rules across machines, put them in a tracked `.gitignore` at `$HOME` and `dot add -f ~/.gitignore`.

## When user asks "should I use Stow / chezmoi / symlinks?"

1. Run discovery first
2. If a working setup exists, lead with **what they already have** and recommend the worktree trick or aliases
3. If starting from scratch, recommend **plain `ln -s` + Makefile** unless they need templating (chezmoi) or have 50+ paths (Stow)
4. Don't recommend tools for the sake of "best practice" — the user's friction point matters more than tool sophistication
