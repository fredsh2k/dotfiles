---
name: yi
description: Use when debugging or configuring a YI 4K/YDXJ2/Z16 action camera over Wi-Fi, ADB, broken touchscreen workflows, timestamp/date stamp settings, camera_clock drift, or the YI Action app failing to install.
---

# YI Camera Debugging

## Overview
Use the camera's local JSON control socket before guessing SD-card or firmware tricks. The YI 4K / YDXJ2 / Z16 exposes HTTP on `192.168.42.1:80` and a raw TCP API on `192.168.42.1:7878` when the phone/computer is on the camera Wi-Fi.

## Proven Facts
YI Action app package: `com.xiaomi.xy.sportscamera`.
Galaxy S26 Ultra cannot install the APK if it is `armeabi-v7a` only: Android has no 32-bit ABI support.
Camera model observed: `Z16`, firmware `Z16V13L_1.10.9_build-20180622051856_git-efbdfd85_r2748`, hardware `YDXJ2_V13LB`.
Handshake response includes `model` and `rtsp`, e.g. `rtsp://192.168.42.1/live`.

## Safe Workflow
1. Confirm connectivity from the device on camera Wi-Fi: `ping 192.168.42.1`, HTTP root, then TCP port `7878`.
2. Start a session with `msg_id:257` and use the returned `param` as the token.
3. Read settings before writing: `msg_id:3` for all current settings, `msg_id:1` for one setting.
4. Only write settings whose key and valid values were confirmed by reads/decompiled app code.
5. Read back every setting after writing.

## API Quick Reference
Messages are raw JSON on TCP port `7878`. The app writes JSON without newline delimiters; responses can be concatenated JSON objects.

| Purpose | JSON |
| --- | --- |
| Start session | `{"msg_id":257,"param":0,"token":0,"heartbeat":1}` |
| Heartbeat reply | `{"msg_id":1793,"token":TOKEN,"rval":0}` |
| Read all current settings | `{"msg_id":3,"token":TOKEN}` |
| Read one setting | `{"msg_id":1,"type":"video_stamp","token":TOKEN}` |
| Write one setting | `{"msg_id":2,"type":"camera_clock","param":"YYYY-MM-DD HH:mm:ss","token":TOKEN}` |

Confirmed setting keys and values:

| Setting | Values / Format | Notes |
| --- | --- | --- |
| `camera_clock` | `yyyy-MM-dd HH:mm:ss` | App sets local phone time, not UTC. |
| `video_stamp` | `off`, `date`, `time`, `date/time` | Use `date/time` for video timestamp overlay. |
| `photo_stamp` | `off`, `date`, `time`, `date/time` | Independent from video. |
| `stamp_enable` | `on`, `off` | If `off`, app hides video timestamp option on some modes. |
| `app_status` | `idle`, etc. | Prefer writing clock while idle. |

## Probe Tool
Use bundled `yi-camera-probe.py` to avoid line-oriented socket bugs:

```bash
python3 ~/.agents/skills/yi-camera-debugging/yi-camera-probe.py '{"msg_id":3,"token":null}'
python3 ~/.agents/skills/yi-camera-debugging/yi-camera-probe.py '{"msg_id":1,"type":"camera_clock","token":null}'
python3 ~/.agents/skills/yi-camera-debugging/yi-camera-probe.py '{"msg_id":2,"type":"video_stamp","param":"date/time","token":null}'
```

`token:null` is replaced with the session token returned by `msg_id:257`.

## Known Good Clock Fix
Use the local timestamp format the app uses:

```bash
NOW=$(date '+%Y-%m-%d %H:%M:%S')
python3 ~/.agents/skills/yi-camera-debugging/yi-camera-probe.py \
  "{\"msg_id\":2,\"type\":\"camera_clock\",\"param\":\"$NOW\",\"token\":null}" \
  '{"msg_id":1,"type":"camera_clock","token":null}' \
  '{"msg_id":1,"type":"video_stamp","token":null}'
```

## Common Mistakes
Do not use `readline()` or expect newline-delimited JSON; the camera concatenates objects.
Do not close the socket immediately after writing the handshake; keep it open long enough for responses.
Do not use stale tokens from previous sessions.
Do not assume `msg_id:5` options works for stamp settings; observed response was `{"rval":-7,"msg_id":5}` for `video_stamp` and `photo_stamp`.
Do not retry installing the 32-bit YI Action APK on a 64-bit-only phone.
Do not start with telnet, firmware scripts, `autoexec.ash`, or `system.pref.upload` when the JSON API works.

## SD-Card Fallbacks
Only use these if the JSON API cannot solve the problem:

| File | Purpose |
| --- | --- |
| `system.pref.download` | Dump settings to SD on boot. |
| `system.pref.upload` | Import settings from SD on boot. Riskier; verify exact content first. |
| `autoexec.ash` | Execute RTOS commands on boot. |
| `console_enable.script` | Enable telnet root/no password on camera Wi-Fi. |

Public reference repo: `https://github.com/irungentoo/Xiaomi_Yi_4k_Camera`.
