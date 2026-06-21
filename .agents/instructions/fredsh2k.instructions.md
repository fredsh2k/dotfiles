---
applyTo: "**/*"
---

Use zsh as the terminal shell.
Use code-insiders over code for VS Code. This applies everywhere, including `gh codespace code` (always pass `--insiders`) and any other tool that can launch VS Code.

IMPORTANT: Always use modern CLI tools instead of legacy ones.
ALWAYS use `rg` (ripgrep) instead of grep or built-in search tools
ALWAYS use `fd` instead of find or built-in glob tools
ALWAYS use `sd` instead of sed for find-and-replace
ALWAYS use `rip` instead of rm (safer, uses graveyard)

NEVER `git push` without my explicit approval. Stage and commit freely, but always pause and ask before pushing to any remote — including dotfiles, personal repos, and work repos. If I explicitly grant scoped push approval for a named task, branch, PR, or plan, you may push commits that stay within that scope until I revoke it or the task is complete. This applies to `git push`, `gh pr merge`, force-pushes, and anything else that mutates a remote.
When using git commit use simple one-liner messages prefixed with fix: or feat: or docs: etc.
When using git add use specific file paths, never use -A or --all or . (dot).
After creating new files, always `git add` them so they can be reviewed in LazyVim with `space g D` (Diffview). Untracked files don't appear in diffview.
When using git checkout use short branch names without my username or other prefixes.

When using gh cli use --no-pager or cat to avoid pager terminal buffers.
When creating or editing GitHub issue/PR bodies with `gh`, use a real multiline body file or heredoc command substitution. Never pass escaped `\n` sequences inside a quoted `--body` string when you intend Markdown newlines.
When creating PRs always create them as draft, use the PR template if available, use a concise title prefixed with fix:, feat:, docs:, chore:, refactor:, test:, or ci: as appropriate, and mention part of issue number at the end of the PR description.
When writing PR descriptions, keep them short and precise. Follow the repo's PR template when available, but do not keep meaningless section titles like "Summary", "Overview", or "Checklists" just to fill space. If the template has headings but the content is short, collapse it into concise paragraphs and only keep headings that add useful structure.
When creating issues, always make them as high level requirements, no need to deep dive into specific implementations.
Make sure to create sub-issues where appropriate for easier tracking using the gh graphql api.
When analyzing gh pr checks failures, always save the logs to a file and use ripgrep to search for relevant error messages instead of running gh pr checks repeatedly.
Do not reply to people comments on PRs.

Before cloning any repo, always check if it already exists under /Users/fsherman/Code/GitHub/ first.
Repos may include additional repo-specific agent instructions at `.github/copilot-instructions.md`; when working in a repo, check and follow that file if present.
When starting non-trivial work in a git repo, prefer using dedicated git worktrees so multiple features can progress independently in the same repo. Before creating a new worktree, fetch and fast-forward the local default branch (`main` or `master`) from its upstream when the worktree is clean and it is safe to do so; then create the feature worktree from that updated local branch. If the local default branch has local/unmerged work or cannot be checked out safely, fetch and base the worktree on the remote-tracking default branch instead, and mention the fallback. Use separate worktrees for local plan iteration and implementation: a plan-only branch/worktree may commit `plans/` checkpoints locally for LazyVim/Diffview review, but must never be pushed or merged; the implementation worktree contains code changes intended for PRs. Use short branch names, place worktrees in a local `worktrees/` or `.worktrees/` directory when practical, and avoid worktrees only for small single-file edits or when the user asks to work in the current checkout.
Store all planning and progress documents in a `plans/` directory at the repo root, named with the convention `feature-name-plan.md` (e.g. `noble-heaven-lab-host-plan.md`). Create the directory if it doesn't exist.
Plans and progress files are scratch — never `git add`/commit them in implementation branches, and add `plans/` to `.gitignore` if not already ignored. Keep plans short and high-level: no code blocks or implementation details, just intent, decisions, and step lists. Reference code via `path/to/file.ext:line` instead of pasting it. Prefer bullets over prose, call out assumptions/open questions explicitly, and update the plan/progress markdown as work progresses rather than letting it go stale.
When researching internal GitHub infrastructure, platforms, or services, read the thehub repo at `/Users/fsherman/Code/GitHub/thehub` for documentation.

## Reading web messages

Use the Playwright MCP browser to read Outlook, Slack, WhatsApp, and Teams messages. The shared browser profile is configured in opencode with `@playwright/mcp` and `--user-data-dir=/Users/fsherman/.chrome-agent-profile`; prefer reusing existing authenticated tabs before opening new ones.

Treat message reading as read-only unless I explicitly ask you to send, react, archive, delete, or otherwise mutate state. It is OK to navigate, select chats/channels/mail, search within the app, and summarize visible messages.

Known useful tabs/apps: Outlook Mail at `https://outlook.cloud.microsoft/mail/`, Slack GitHub-grid at `https://app.slack.com/client/E01DLHH5JM6/`, WhatsApp at `https://web.whatsapp.com/`, and Teams at `https://teams.cloud.microsoft/`. If authentication is required, ask me to complete SSO/Okta/QR/login in the browser and then continue.

Dotfiles live as a regular git clone at `~/Code/Personal/dotfiles`, with tracked files symlinked into `$HOME`.
Use `git -C ~/Code/Personal/dotfiles ...` (or the `dot` alias) for all dotfile git operations. Edit files via the repo path so changes flow through the symlinks.
Remote: https://github.com/fredsh2k/dotfiles.git (do NOT push without approval — see git-push rule above).
This instructions file (and anything under `~/.agents/` or `~/.config/opencode/AGENTS.md`) is a symlink into the dotfiles repo. To edit it, always go through the canonical path `~/Code/Personal/dotfiles/.agents/instructions/fredsh2k.instructions.md` — not the symlinked location your system prompt may advertise.

## Local troubleshooting

If Tailscale profile switching to `fredsh2k@gmail.com` times out and logs show `auth window cannot open malformed URL`, back up `~/Library/Preferences/io.tailscale.ipn.macsys.plist`, delete only `com.tailscale.cached.currentProfile` and `com.tailscale.cached.profiles` with `defaults delete`, run `killall cfprefsd`, then relaunch Tailscale. This clears stale cached profile metadata while preserving the app install and VPN configuration.

## Local opencode development

Use one Ghostty instance with herdr. A herdr workspace is a single task/project context and should have a short 1-2 word task name. Work repos live under `~/Code/GitHub/`; use a first `plan` tab there for cross-repo reading/planning, then do code edits in separate repo-root tabs named for the repo, launching opencode from paths like `~/Code/GitHub/heaven` or `~/Code/GitHub/puppet` with tab names `heaven`, `puppet`. Personal/open-source repos live under `~/Code/Personal/` and are usually single-repo tasks, so the first tab can be opened directly in that repo.

The local opencode source checkout lives at `~/Code/Personal/opencode`. When changing opencode behavior or adding local features, edit source files in that repo rather than installed files under `~/.opencode/`.

Use the `opencode-tui` zsh function for the fast local compiled build against the current repo. Use `opencode-tui-source` when validating source edits; it changes into `~/Code/Personal/opencode/packages/opencode` and runs `src/index.ts` with Bun, passing the original working directory as the project path. Plain `opencode` still resolves to the installed binary at `~/.opencode/bin/opencode` and will not include local source edits.

For opencode source changes, follow the repo instructions in `~/Code/Personal/opencode/AGENTS.md` and `~/Code/Personal/opencode/packages/opencode/AGENTS.md`. Run tests from package directories such as `~/Code/Personal/opencode/packages/opencode`; never run package tests from the opencode repo root.

If a local feature needs manual TUI validation, tell me to run `source ~/.zshrc && opencode-tui-source` in the relevant repo pane. If startup speed matters more than local source edits, use installed `opencode`, `opencode-tui`, or `opencode-attach` instead, because the local Bun TypeScript launcher is slower than the compiled installed binary.
