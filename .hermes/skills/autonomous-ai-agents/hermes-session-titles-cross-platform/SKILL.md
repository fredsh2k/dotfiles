---
name: hermes-session-titles-cross-platform
description: Name Hermes sessions so they can be resumed across platforms (TUI ↔ Discord/Telegram). Avoids the /title pending-flush gotcha that silently breaks /resume.
---

# Hermes session titles & cross-platform /resume

## When to use

- Naming a long-running session so you can `/resume <name>` later
- Switching from TUI to Discord/Telegram and wanting to continue the same conversation
- Diagnosing "/resume says no named sessions found" or "/resume <name> finds nothing"

## The two gotchas

### Gotcha 1: `/title` is lazy AND the session row may not exist yet

Two stacked issues:

(a) **The session row is not created on TUI startup.** It's only inserted into `state.db` when the first assistant turn writes a message. A freshly-launched TUI has a `session_id` displayed by `/title`, but `sqlite3 ~/.hermes/state.db "SELECT id FROM sessions WHERE id='<that_id>';"` returns nothing. `hermes sessions rename <id> "..."` fails with **"Session '<id>' not found"** because there's no row to UPDATE.

(b) **`/title <name>` writes lazily even when the row exists.** It stashes the name in `self._pending_title` (`cli.py:5643`) and only flushes via `set_session_title()` after the **next assistant turn completes** (`cli.py:3044-3048`).

Combined symptom: `/title` shows `Title (pending): "..."` and `Session ID: <id>` — but BOTH the row and the title are missing from disk.

**Fix:** send any message (e.g. `hi`) in the TUI. The first turn (1) creates the session row, then (2) flushes the pending title in the same post-turn hook. After that, the row + title are persisted.

### Gotcha 2: `/resume` (no args) filters by source

On Discord, `/resume` with no args calls `list_sessions_rich(source="discord", ...)` (`gateway/run.py:6965-6967`). It **only lists sessions whose `source` column matches the current platform**. TUI sessions (`source='tui'`) are invisible to Discord's `/resume` browser, even when titled.

But `resolve_session_by_title()` (`hermes_state.py:653`) is **source-agnostic** — typing `/resume <name>` explicitly on any platform will find the session regardless of its origin source.

## Recommended workflow

### Setting a title that survives platform switches

**Most reliable — `/title` + send a message:**
```
/title my session name
hi            # any message — creates the row AND triggers the pending flush
```
This works whether or not the row already exists.

**CLI rename — only if a row already exists:**
```bash
hermes sessions rename <session_id> "my session name"
```
Synchronous DB write (`hermes_cli/main.py:7918`), but **fails with "not found" on TUI sessions that haven't sent a turn yet**. Use the message-flush approach for those.

**Find the session ID:**
```bash
hermes sessions list
# or in the TUI:
/title         # echoes the current session_id
```

### Resuming on a different platform

Always type the name explicitly — don't rely on the listing:
```
/resume my session name
```

The bare `/resume` listing only shows sessions originating from the current platform. The named lookup is global.

### Verifying a title is persisted

```bash
sqlite3 ~/.hermes/state.db \
  "SELECT id, source, title FROM sessions WHERE title IS NOT NULL ORDER BY started_at DESC LIMIT 5;"
```

If `title` is NULL despite `/title` showing it as pending → the lazy flush didn't fire. Use `hermes sessions rename`.

## Pitfalls

- **Don't change `source` to bridge platforms.** Tempting to `UPDATE sessions SET source='discord'` to make a TUI session show in Discord's `/resume` listing — but this breaks ownership. Use the explicit-name workaround instead.
- **Cross-platform continuity ≠ live multi-platform.** A session can be resumed from any platform but is only active in one place at a time. Switching platforms forks the active surface, not the history.
- **Per-platform listing is intentional.** Not a bug that Discord's `/resume` browser hides TUI sessions — prevents leaking laptop work into chat channels. The named lookup is the supported escape hatch.
- **The `/title` lazy-flush is arguably a bug** since PR #2379 made session rows eager. Worth filing upstream. Until fixed, prefer `hermes sessions rename`.

## Verification checklist

After naming a session, before relying on cross-platform resume:

1. `/title` shows the name without "(pending)" prefix → flushed
2. `sqlite3 ~/.hermes/state.db "SELECT title FROM sessions WHERE id='<id>';"` returns the name → on disk
3. On the target platform: `/resume <name>` returns "↻ Resumed session ..." → resolution works
