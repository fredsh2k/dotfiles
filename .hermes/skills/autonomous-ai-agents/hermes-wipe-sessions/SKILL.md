---
name: hermes-wipe-sessions
description: Bulk-delete Hermes session history from the SQLite store. Use when the user wants a fresh start, to free disk, or to scrub past chats from session_search recall.
---

# Wipe Hermes Sessions

Hermes stores chat history in `~/.hermes/state.db` (SQLite + WAL). Sessions feed `session_search`, `hermes -c`, and `hermes -r`. Deleting them is irreversible — offer to export first.

## When to use
- User says "clear all sessions", "start fresh", "wipe history", "nuke my chats"
- User wants `session_search` recall reset
- Disk pressure on `~/.hermes/state.db*`

## Pre-flight (always)
```zsh
hermes sessions stats          # how much will disappear
hermes sessions list | head    # confirm scope
```
Optional backup:
```zsh
hermes sessions export ~/hermes-sessions-backup-$(date +%Y%m%d).jsonl
```

## Method 1 — `prune --older-than 0` (preferred, one shot)
Works even from inside an active session — the active one is skipped automatically.
```zsh
hermes sessions prune --older-than 0 --yes
```
Scope to one transport with `--source cli|tui|telegram|discord|...` to keep others.

## Method 2 — loop over `sessions list` (when you need to keep the current one explicitly)
The `list` table format: header (line 1) + separator (line 2) + rows from line 3. ID is the **last whitespace field** of each row. Schema as of Apr 2026:
```
Preview                                            Last Active   Src    ID
───────────────────────────────────────────────────────────────────────────
which cli commands ...                             2m ago        tui    20260420_132504_629c57
```
Older builds had a leading `Title` column — `awk '{print $NF}'` on data rows is robust to both.

```zsh
# Delete everything except the newest (presumed active) session
CURRENT=$(hermes sessions list 2>/dev/null | awk 'NR>=3 && NF>0 {print $NF; exit}')
hermes sessions list 2>/dev/null \
  | awk 'NR>=3 && NF>0 {print $NF}' \
  | grep -v "^$CURRENT$" \
  | while read id; do hermes sessions delete "$id" -y; done
```

To finish wiping the current session: `exit` the TUI, then `hermes sessions delete <id> -y`, then `hermes chat`.

## Method 3 — nuke the DB (heaviest)
Drops sessions AND state.db metadata (auth status cache, gateway state stays separate). DB recreates on next launch.
```zsh
rip ~/.hermes/state.db ~/.hermes/state.db-shm ~/.hermes/state.db-wal
hermes chat
```

## Pitfalls
- The active session can't delete itself while open — Method 1 silently skips it; Method 2 must skip it explicitly or the `delete` call no-ops.
- `hermes sessions list` paginates by default; pipe through itself or use `--limit 1000` if a future build supports it. Currently the loop will only catch what `list` shows — re-run until empty if needed.
- `--older-than 0` matches every session (anything older than 0 days). `--older-than 1` keeps today.
- `state.db-shm` / `state.db-wal` are SQLite's shared-memory + write-ahead-log; deleting them while Hermes is running corrupts state. Always exit Hermes first for Method 3.
- `gateway_state.json` is separate (transport state), not session data — leave it alone.
- macOS: user prefers `rip` over `rm`.

## Verify
```zsh
hermes sessions stats          # should show 0 (or 1 if active)
hermes sessions list           # should be empty (or just current)
```

## Starting fresh after wipe
- `hermes chat` — new session, no resume
- Just running `hermes chat` (no `-c`/`-r`) **always** starts fresh — wiping is only needed to drop history, not to get a clean session.
