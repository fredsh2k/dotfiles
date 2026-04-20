---
name: discord-notify
description: Sends notifications to the user's phone via a Discord webhook. Use whenever the user wants to be notified, alerted, pinged, or pushed about something from a script, cron job, launchd agent, CI failure, build status, or long-running task — phrases like "notify me", "send me a notification", "ping my phone", "let me know when", "alert me", "post to discord", "send to my channel". The user's webhook URL lives at ~/.config/secrets/discord-webhook (chmod 600, gitignored). A `notify` zsh function is defined in ~/.zshrc. Common gotcha: Discord blocks Python urllib's default User-Agent with a Cloudflare 1010 error — always set a custom UA when posting from Python. Discord message content is capped at 2000 chars; chunk longer payloads.
---

# discord-notify

Push notifications to the user's phone via Discord webhook.

## Setup (already done — reference only)

- Webhook URL: `~/.config/secrets/discord-webhook` (chmod 600, gitignored via `.config/secrets/` in `~/Code/Personal/dotfiles/.gitignore`)
- `notify` zsh function defined in `~/.zshrc` (search for `notify()`)
- User's Discord channel: `#notify` in their personal server

If the user wants a NEW webhook (different channel/server), guide them: Discord channel settings → Integrations → Webhooks → New Webhook → Copy URL → save to a new file under `~/.config/secrets/`.

## From the shell

```sh
notify "build done"                        # plain message
notify "deploy" "prod is green"            # bolded **title** + body
some-command 2>&1 | notify                 # pipe stdout/stderr
make test || notify "test failed in $(pwd)"
```

The `notify` function uses `curl` + `jq` and reads the webhook from `~/.config/secrets/discord-webhook`.

## From Python

```python
import json, urllib.request
from pathlib import Path

webhook = (Path.home() / ".config/secrets/discord-webhook").read_text().strip()
req = urllib.request.Request(
    webhook,
    data=json.dumps({"content": message[:1900]}).encode(),
    headers={
        "Content-Type": "application/json",
        "User-Agent": "my-script/1.0",   # CRITICAL — see gotcha below
    },
    method="POST",
)
urllib.request.urlopen(req, timeout=10)
```

## From other languages

Just POST JSON to the webhook URL. Body shape:

```json
{ "content": "message here", "username": "optional override", "avatar_url": "optional" }
```

Set `Content-Type: application/json` and a custom `User-Agent`.

## Gotchas

- **Cloudflare 1010 / 403** when posting from Python: Discord's edge blocks `Python-urllib/x.y` UA. Always set `User-Agent` to anything custom. `curl` works without a custom UA. `requests` library is also fine (its default UA is allowed).
- **2000-char limit** on `content`. Truncate or split into multiple posts. Use Discord embeds (`embeds: [{...}]`) for richer/longer formatting up to 6000 chars total.
- **Markdown supported**: `**bold**`, `*italic*`, `__underline__`, `` `code` ``, ``` ```lang\ncode\n``` ```, `> quote`, `||spoiler||`, `[text](url)`. Headers (`#`, `##`, `###`) render too.
- **Mentions**: `<@USER_ID>` for users, `<@&ROLE_ID>` for roles, `@everyone` / `@here`. Need `allowed_mentions` field to suppress unintended pings.
- **Rate limit**: ~5 req/sec/webhook before Discord 429s. For chunked messages add a small `sleep` between posts.
- **Phone notifications silent?** User must set channel notification setting to "All Messages" in the Discord mobile app (bell icon).

## Adding a new webhook for a different channel

1. Discord → channel → Edit Channel → Integrations → Webhooks → New Webhook → Copy URL
2. `echo '<url>' > ~/.config/secrets/discord-<purpose>` && `chmod 600 ~/.config/secrets/discord-<purpose>`
3. In scripts, point at that file instead of `discord-webhook`.

## Related

- `macos-launchd-job` skill — for scheduling notifications nightly/hourly.
