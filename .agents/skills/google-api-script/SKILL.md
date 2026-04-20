---
name: google-api-script
description: Bootstrap, debug, and operate Python scripts that talk to Google APIs using OAuth 2.0 user credentials (Calendar, Tasks, Gmail, Drive, Sheets, Docs, etc.). Use whenever the user wants to script anything against Google services, mentions Google Calendar/Tasks/Gmail/Drive/Sheets API, asks about google-api-python-client / google-auth / google-auth-oauthlib, OAuth client_secret JSON, OAuth consent screen, scopes (calendar.readonly, tasks, gmail.readonly, etc.), refresh tokens, or hits errors like "400 malformed request", "access_denied", "invalid_grant", "Token has been expired or revoked", or sees an unexpected app name in the OAuth consent screen. Covers the full lifecycle: GCP project setup, enabling APIs, configuring the OAuth consent screen (External + test users + scope list), creating Desktop OAuth client, writing scripts that cache tokens to ~/.config/secrets/, refreshing expired tokens, and migrating user-OAuth secrets into GitHub Actions workflows. The user's Google scripts live in ~/Code/Personal/dotfiles/bin/ (notify-daily, google-task-add); their Python venv is at ~/.local/share/notify-daily/venv.
---

# google-api-script

Operational guide for personal Python scripts that call Google APIs via OAuth 2.0 user credentials.

## File layout (user convention)

```
~/.config/secrets/                          chmod 700, gitignored
├── google-oauth-client.json                Desktop OAuth client (downloaded from GCP)
├── google-oauth-token.json                 Cached user token (READ scopes)
└── google-oauth-token-write.json           Cached user token (WRITE scopes, separate file)

~/Code/Personal/dotfiles/bin/               Tracked scripts
├── notify-daily                            Calendar + Tasks readonly
└── google-task-add                         Tasks write (uses token-write.json)

~/.local/share/notify-daily/venv/           Python venv (not tracked)
```

Two-token pattern: keep readonly and write tokens in separate cache files so a write-scope token leak doesn't compromise daily readonly automation, and so the readonly token (used in CI) is never accidentally swapped for a wider one.

## One-time GCP setup

1. https://console.cloud.google.com → **New Project** (or pick existing)
2. **APIs & Services → Library** → enable each API the script needs (e.g. `Google Calendar API`, `Google Tasks API`, `Gmail API`)
3. **APIs & Services → OAuth consent screen** (or "Google Auth Platform" in newer UI):
   - User Type: **External**
   - **App name**: pick something recognizable — this is what users see in the consent dialog (NOT the GCP project name; these are separate fields)
   - User support email + developer contact: your email
   - **Scopes**: add EVERY scope you'll request, both readonly and write. If a scope isn't listed here, requesting it returns `400 malformed request`.
   - **Test users**: add your own Gmail address while in Testing status.
   - **Publish the app** (Audience tab → "Publish App"). For personal scripts this is strongly recommended — see "Publishing status" section below.
4. **APIs & Services → Credentials** → **Create Credentials → OAuth client ID** → **Desktop app** → download JSON → save as `~/.config/secrets/google-oauth-client.json`, `chmod 600`.

## Python venv bootstrap

```sh
python3 -m venv ~/.local/share/<tool>/venv
~/.local/share/<tool>/venv/bin/pip install -q google-api-python-client google-auth google-auth-oauthlib
```

Script shebang options:
- **Local-only**: `#!/Users/fsherman/.local/share/<tool>/venv/bin/python3` (hardcoded, fast, no PATH munging)
- **Portable (works in CI too)**: `#!/usr/bin/env python3` and let CI install deps via `pip install` step

## Auth flow boilerplate

```python
from pathlib import Path
import json, os, sys
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SECRETS = Path.home() / ".config" / "secrets"
CLIENT_FILE = SECRETS / "google-oauth-client.json"
TOKEN_FILE = SECRETS / "google-oauth-token.json"
SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]

def get_creds():
    # Env vars first (CI), file fallback (local).
    token_env = os.environ.get("GOOGLE_OAUTH_TOKEN")
    creds = None
    if token_env:
        creds = Credentials.from_authorized_user_info(json.loads(token_env), SCOPES)
    elif TOKEN_FILE.exists():
        creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
    if creds and creds.valid:
        return creds
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        if not token_env:
            TOKEN_FILE.write_text(creds.to_json())
            TOKEN_FILE.chmod(0o600)
        return creds
    # Need browser OAuth — only works locally
    if os.environ.get("CI"):
        sys.exit("token expired, cannot run interactive OAuth in CI")
    flow = InstalledAppFlow.from_client_secrets_file(str(CLIENT_FILE), SCOPES)
    creds = flow.run_local_server(port=0)  # opens browser, listens on random port
    TOKEN_FILE.write_text(creds.to_json())
    TOKEN_FILE.chmod(0o600)
    return creds
```

## Common scopes (readonly = lowest blast radius)

| API | Scope | Notes |
|---|---|---|
| Calendar (read) | `https://www.googleapis.com/auth/calendar.readonly` | All calendars + events |
| Calendar (write) | `https://www.googleapis.com/auth/calendar.events` | Events only, not settings |
| Tasks (read) | `https://www.googleapis.com/auth/tasks.readonly` | All task lists |
| Tasks (write) | `https://www.googleapis.com/auth/tasks` | Create/update/delete tasks |
| Gmail (read) | `https://www.googleapis.com/auth/gmail.readonly` | Read messages + metadata |
| Gmail (send) | `https://www.googleapis.com/auth/gmail.send` | Send only, no read |
| Drive (read) | `https://www.googleapis.com/auth/drive.readonly` | All Drive files |
| Drive (file-scoped) | `https://www.googleapis.com/auth/drive.file` | Only files this app created |
| Sheets | `https://www.googleapis.com/auth/spreadsheets` | Full sheets read+write |

Always prefer the narrowest scope. Mixing readonly + write in one token is fine for personal use but a separate write-token file is cleaner.

## Common errors

| Symptom | Cause | Fix |
|---|---|---|
| `400. That's an error. The server cannot process the request because it is malformed.` | Requested scope is not listed on the OAuth consent screen, OR app metadata incomplete | Add the missing scope under OAuth consent screen → Scopes → Save. If scope IS listed, ensure all required app metadata fields are filled in. |
| Browser shows wrong app name (e.g. "hermes" when project is "opencode") | OAuth consent screen "App name" field is stale | Edit App in consent screen → Branding tab, change name, Save (project name in GCP is separate from app name) |
| `access_denied` after clicking Allow | Your email isn't in the Test Users list while app is unverified, OR app is in Testing and you're not a test user | Add test user under OAuth consent screen → Test users, OR publish the app |
| `invalid_grant: Token has been expired or revoked` | Refresh token revoked: app in Testing status >7 days unused, user revoked at myaccount.google.com/permissions, or OAuth client regenerated | Delete cached token JSON, re-run script for fresh OAuth. Publish the app to prevent the 7-day issue. |
| `403 quota exceeded` | Hit per-user or per-project quota | Check Console → APIs & Services → Quotas; usually pay-as-you-go quotas auto-raise |
| `redirect_uri_mismatch` | Using web app client instead of Desktop client | Recreate as **Desktop app** type in Credentials |
| Refresh token missing on subsequent runs | First auth used `prompt=none` or `access_type=online` | Use `flow.run_local_server()` which sets `access_type=offline`; revoke + re-auth if cached token lacks refresh |
| `webbrowser.open` doesn't open browser (CLI-driven) | Non-interactive shell, no DISPLAY | On macOS `open` works regardless; on Linux/CI you can't do interactive OAuth — bake refresh token into env var |

## Migrating to CI (GitHub Actions)

The boilerplate above already supports env-var secrets. Workflow setup:

```yaml
- env:
    GOOGLE_OAUTH_CLIENT: ${{ secrets.GOOGLE_OAUTH_CLIENT }}
    GOOGLE_OAUTH_TOKEN:  ${{ secrets.GOOGLE_OAUTH_TOKEN }}
  run: ./bin/notify-daily
```

Set secrets:
```sh
gh secret set GOOGLE_OAUTH_CLIENT < ~/.config/secrets/google-oauth-client.json
gh secret set GOOGLE_OAUTH_TOKEN  < ~/.config/secrets/google-oauth-token.json
```

The refresh token in `GOOGLE_OAUTH_TOKEN` is what keeps CI working long-term — it auto-refreshes the access token on each run. If it stops working, re-auth locally and re-set the secret.

## DST + cron-only-UTC handling

GHA cron is UTC only. To run "at X:00 local time year-round" through DST:

```yaml
on:
  schedule:
    - cron: '0 19,20 * * *'   # 22:00 Asia/Jerusalem in IDT (UTC+3) AND IST (UTC+2)
```

Then in the script:
```python
import os, datetime as dt
from zoneinfo import ZoneInfo
target = os.environ.get("TARGET_HOUR")
if target:
    if dt.datetime.now(tz=ZoneInfo("Asia/Jerusalem")).hour != int(target):
        sys.exit(0)  # other UTC slot will fire at the right local hour
```

Schedule both possible UTC times → one is always the target local hour → script exits cleanly on the wrong one.

## Publishing status (Testing vs Production)

Two states for the OAuth consent screen, found under **Google Auth Platform → Audience** (new UI) or **OAuth consent screen → Publishing status** (old UI):

| State | Behavior |
|---|---|
| **Testing** | Only emails listed under "Test users" can authorize. **Refresh tokens revoked after 7 days of inactivity** — user must re-auth via browser. |
| **In production** | Anyone with a Google account can authorize (they'd see "unverified app" warning the first time, then proceed). **Refresh tokens don't expire from inactivity.** |

**Publish for personal scripts.** The "anyone can authorize" sounds scary but means nothing in practice: tokens are issued per-user, only your account's tokens can read your data. Publishing only stops the 7-day refresh-token expiry. No Google verification process needed for low-risk readonly scopes (Calendar, Tasks, Drive, Gmail readonly) — verification is only required if requesting sensitive scopes (gmail.modify, drive full read/write of arbitrary files) AND going beyond 100 users.

To publish: GCP Console → opencode project → APIs & Services → Audience → **Publish App**. 5-second confirmation dialog. Done.

**The user's `opencode` GCP project (nodal-condition-493812-h4) is published as of 2026-04-20.** Refresh tokens won't expire from inactivity for any of `notify-daily`, `briefing-morning`, or `google-task-add`.

## Token rotation

OAuth refresh tokens for personal Gmail accounts:
- Don't expire by time (unlike GitHub PATs)
- DO expire if app stays in **Testing** status for 7 days without use → re-auth required
- After **Publishing**: don't expire from inactivity
- Revoked if user removes app at https://myaccount.google.com/permissions
- Revoked if OAuth client is rotated/regenerated in GCP Credentials

## Anti-patterns

- Don't commit `client_secret.json` or `token.json` — both go in `~/.config/secrets/`, gitignored.
- Don't use service accounts for personal Gmail accounts — service accounts need domain-wide delegation which requires Google Workspace admin.
- Don't request write scopes when readonly suffices.
- Don't share a single token across read + write — use separate cache files.
- Don't put OAuth client ID/secret as GHA repo secrets if the repo is public — actually safe (encrypted, fork-PRs blocked) but creates blast radius if you ever leak; prefer fine-grained least-privilege scopes anyway.
