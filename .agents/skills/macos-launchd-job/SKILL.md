---
name: macos-launchd-job
description: Creates, installs, loads, debugs, and removes scheduled background jobs on macOS using launchd LaunchAgents. Use whenever the user wants to run something on a schedule, periodically, nightly, hourly, at boot, on login, every N minutes, as a daemon, as a background job, "like cron but on mac", or mentions launchd, launchctl, plist, LaunchAgent, LaunchDaemon, StartCalendarInterval, StartInterval, KeepAlive, RunAtLoad, pmset, scheduled wake, "wake my mac". Prefer launchd over cron on macOS — cron runs with a minimal env and is being deprecated by Apple. User's plists are tracked in ~/Code/Personal/dotfiles/Library/LaunchAgents/ and symlinked into ~/Library/LaunchAgents/. Common gotchas covered: `launchctl load` is deprecated (use `bootstrap`), env vars are NOT inherited from shell, paths must be absolute, file perms matter, gui/501 is the user's domain, and `pmset repeat wake` is required to fire jobs while asleep (with hardware caveats around lid-closed-on-battery).
---

# macos-launchd-job

Schedule background jobs on macOS via per-user `launchd` agents.

## File layout convention

- Plist source of truth: `~/Code/Personal/dotfiles/Library/LaunchAgents/com.fredsh2k.<name>.plist`
- Symlinked to runtime: `~/Library/LaunchAgents/com.fredsh2k.<name>.plist`
- `Label` in the plist must equal the filename without `.plist`.
- Reverse-DNS naming: `com.fredsh2k.<name>` (the user owns no domain, but the convention prevents collisions and matches Apple's expectation).

```sh
ln -sf ~/Code/Personal/dotfiles/Library/LaunchAgents/com.fredsh2k.<name>.plist \
       ~/Library/LaunchAgents/com.fredsh2k.<name>.plist
```

## Plist template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.fredsh2k.<name></string>

  <key>ProgramArguments</key>
  <array>
    <string>/absolute/path/to/script-or-binary</string>
    <string>--flag</string>
    <string>arg</string>
  </array>

  <!-- Pick ONE schedule mechanism: -->

  <!-- Daily at 22:00 -->
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>22</integer>
    <key>Minute</key><integer>0</integer>
  </dict>

  <!-- OR every N seconds -->
  <!-- <key>StartInterval</key><integer>3600</integer> -->

  <!-- OR run on load and keep alive -->
  <!-- <key>RunAtLoad</key><true/> -->
  <!-- <key>KeepAlive</key><true/> -->

  <key>StandardOutPath</key>
  <string>/Users/fsherman/.local/share/<name>/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/fsherman/.local/share/<name>/stderr.log</string>

  <!-- Optional: env vars (NOT inherited from shell) -->
  <!--
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key><string>/Users/fsherman</string>
  </dict>
  -->
</dict>
</plist>
```

`StartCalendarInterval` keys: `Minute`, `Hour`, `Day` (of month), `Weekday` (0=Sun…6=Sat or 7=Sun), `Month`. Omit a key = wildcard. Pass an array of dicts for multiple times.

## Lifecycle commands (modern syntax)

`launchctl load/unload` is deprecated since Big Sur. Use `bootstrap`/`bootout`/`kickstart`/`print`.

User domain target: `gui/$(id -u)` (typically `gui/501`).

```sh
UID=$(id -u)
PLIST=~/Library/LaunchAgents/com.fredsh2k.<name>.plist

# Install / load
launchctl bootstrap gui/$UID "$PLIST"

# Trigger NOW (skip schedule, useful for testing)
launchctl kickstart -k gui/$UID/com.fredsh2k.<name>

# Status (exit code, last run, etc.)
launchctl print gui/$UID/com.fredsh2k.<name>

# Tail logs
tail -f ~/.local/share/<name>/stdout.log ~/.local/share/<name>/stderr.log

# List all user agents
launchctl print gui/$UID | rg com.fredsh2k

# Remove / unload (must do this before editing the plist + reloading)
launchctl bootout gui/$UID "$PLIST"

# Reload after editing plist
launchctl bootout gui/$UID "$PLIST" 2>/dev/null; launchctl bootstrap gui/$UID "$PLIST"
```

## Debugging

- **Job didn't run** → `launchctl print gui/$UID/com.fredsh2k.<name>` shows `last exit code`, `state`, `runs`, `last exit reason`.
- **`Bootstrap failed: 5: Input/output error`** → plist syntax invalid. Validate: `plutil -lint <PLIST>`.
- **`Bootstrap failed: 17: File exists`** → already loaded; `bootout` first.
- **Script runs in shell but not under launchd** → almost always a PATH or env issue. Hardcode absolute paths in the script. For Python tools use a hardcoded venv-python shebang: `#!/Users/fsherman/.local/share/<tool>/venv/bin/python3`.
- **Permissions denied for log files** → ensure `~/.local/share/<name>/` exists and is writable; launchd won't create parent dirs.
- **Wake from sleep behavior**: `StartCalendarInterval` jobs missed during sleep run as soon as the Mac wakes (single missed run, not all of them). To make a job fire reliably even when asleep, schedule a wake event a couple minutes before the trigger time — see "Surviving sleep" below.
- **Logs**: system-level launchd logging via `log stream --predicate 'subsystem == "com.apple.xpc.launchd"' --info`.

## Surviving sleep (`pmset` wake schedules)

launchd alone won't wake the Mac. Pair it with a `pmset` wake event a couple minutes before your scheduled run:

```sh
# Wake every day at 21:58 so a 22:00 launchd job runs reliably.
sudo pmset repeat wake MTWRFSU 21:58:00

# Verify
pmset -g sched

# Cancel all repeating wake schedules
sudo pmset repeat cancel
```

Day codes: `M T W R F S U` (Mon Tue Wed Thu Fri Sat Sun). Other actions: `wake` (wake from sleep), `poweron` (power on if shut down — AC only), `sleep` / `shutdown` / `restart` (the inverse).

**Caveats — when wake DOES NOT happen:**
- ❌ Lid closed on battery (Apple Silicon hardware-enforces sleep; no override exists)
- ❌ Mac fully shut down + on battery
- ❌ Battery dead
- ✅ Lid open on battery or AC — wakes
- ✅ Lid closed on AC with external display (clamshell mode) — wakes

If true 24/7 reliability is needed regardless of laptop state, move the job off the laptop entirely (GitHub Actions scheduled workflow, or any cloud cron service).

`pmset -g sched` also shows transient system-scheduled wakes (calendar app refreshes, OS analytics) — those aren't yours; only the line under `Repeating power events:` is.

## When to use what

| Need                                  | Use                                            |
| ------------------------------------- | ---------------------------------------------- |
| Run at fixed clock time(s)            | `StartCalendarInterval`                        |
| Run every N seconds                   | `StartInterval`                                |
| Run on user login                     | `RunAtLoad` (in a LaunchAgent)                 |
| Always-running daemon                 | `KeepAlive` + `RunAtLoad`                      |
| Watch a file/dir for changes          | `WatchPaths` / `QueueDirectories`              |
| System-wide (runs as root, no GUI)    | LaunchDaemon in `/Library/LaunchDaemons/`     |
| Per-user (has user env, can show GUI) | LaunchAgent in `~/Library/LaunchAgents/` ✅ default |

## Anti-patterns

- Don't use `cron` — Apple has been deprecating it; env is hostile; less observable than launchd.
- Don't put plists only in `~/Library/LaunchAgents/` — track them in dotfiles, symlink in.
- Don't rely on shell env vars (`$PATH`, `$HOME`, anything from `.zshrc`) — launchd doesn't source any rc file. Set explicitly via `EnvironmentVariables` or hardcode.
- Don't forget to `bootout` before editing — running plist is cached; edits don't apply until reload.

## Related

- `discord-notify` skill — pair with launchd for scheduled phone notifications.
