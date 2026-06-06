# NeoTheFox98 — Streaming Project

OBS streaming config, overlays, automation scripts, and Twitch integration for `neothefox98`.

**GitHub**: `https://github.com/NeotericGamer98/streaming` (private)

## Directory Structure

```
Streaming/                          ← git repo root
├── CHANGELOG.md                    (release history)
├── README.md                       (this file)
├── config.ps1.example              (copy to config.ps1, fill in secrets — gitignored)
├── go-live.ps1                     ← one-command launcher
├── end-stream.ps1                  ← graceful cleanup
├── .gitignore
├── .gitattributes
├── overlays/
│   ├── overlay-theme.css           (shared CSS vars, GPU accel, reduced-motion)
│   ├── starting-soon.html          (countdown via ?minutes=N, now-playing slot)
│   ├── brb.html
│   ├── end-of-stream.html
│   ├── technical-difficulties.html
│   ├── chat.html                   (Twitch chat overlay — reads chat-data.json)
│   └── alerts.html                 (sub/raid/follow alert overlay)
├── assets/
│   ├── Bean.png
│   ├── fox_neutral.png
│   ├── fox_talking.png
│   └── twitch-raid.mp3
├── scripts/
│   ├── README.md
│   ├── backup-obs-scenes.ps1       (timestamped backups, keeps last 20)
│   ├── obs-audio-vis.ps1           (audio level overlay daemon)
│   ├── start-stream-mode.ps1       (legacy stream mode launcher)
│   └── protect-twitch-secrets.ps1  (DPAPI-encrypt OAuth tokens)
├── twitch/
│   └── README.md
├── logs/                           (auto-created — gitignored)
└── backups/                        (auto-created — gitignored)
```

## Quick Start

```powershell
# ONE command — starts everything:
.\go-live.ps1

# Options:
.\go-live.ps1 -NoSpotify          # skip music poller
.\go-live.ps1 -NoAudioVis         # skip audio visualizer
.\go-live.ps1 -NoChat             # skip Twitch chat daemon
.\go-live.ps1 -NoHotkeys          # skip global hotkeys + AFK detection
.\go-live.ps1 -Force              # proceed even if existing jobs found
.\go-live.ps1 -Minutes 15         # custom Starting Soon timer

# When stream is over:
.\end-stream.ps1                  # stop daemons + recording, show summary
.\end-stream.ps1 -KeepData        # keep chat/alerts overlay data
```

The launcher validates OBS is running, checks Twitch credentials, guards against duplicate runs, rotates old logs, then starts all daemons as background jobs with auto-restart.

After the configured countdown expires, the Starting Soon scene automatically switches to Streaming.

## Hotkeys

Press these mid-stream (no alt-tabbing needed):

| Combo | Action |
|-------|--------|
| `Ctrl+Shift+B` | Switch to **Be Back Soon** |
| `Ctrl+Shift+S` | Switch to **Streaming** |
| `Ctrl+Shift+T` | Switch to **Technical Difficulties** |
| `Ctrl+Shift+E` | Switch to **End of Stream** |
| `Ctrl+Shift+M` | Toggle **Mic/Aux mute** |
| `Ctrl+Shift+R` | Toggle **Recording** start/stop |

All key combos are configurable in `config.ps1`.

## AFK / Idle Detection

After 5 minutes of no keyboard/mouse input during a stream, the hotkey daemon auto-switches to **Be Back Soon**. When input resumes, it switches back to **Streaming**. Threshold configurable via `$AFK_TimeoutMinutes` in `config.ps1`.

## OBS Automation Hub

All automation scripts live at `.config/opencode/modules/obs/scripts/` and source `Streaming\config.ps1` for shared settings.

| Script | Location | Purpose |
|--------|----------|---------|
| `obs-preflight.ps1` | hub | Preflight — validates OBS config, scenes, audio, overlays, disk before go-live |
| `obs-stream-monitor.ps1` | hub | Daemon — polls OBS every 2s, auto-switches scenes on stream drop |
| `obs-hotkeys.ps1` | hub | Daemon — global hotkeys + AFK/idle detection via Win32 P/Invoke |
| `go-live.ps1` | repo root | Launcher — starts all daemons, auto scene timer, handles restarts |
| `end-stream.ps1` | repo root | Cleanup — stops daemons, stops recording, shows stream summary |
| `spotify-now-playing.ps1` | hub | Polls Spotify window title → writes `overlays/np-data.js` |
| `obs-audio-vis.ps1` | `repo/scripts/` | Daemon — writes audio levels to `overlays/audio-levels.js` |
| `start-stream-mode.ps1` | `repo/scripts/` | Legacy launcher — full stream mode with all daemons |
| `obs-wsapi.psm1` | hub | Shared module — OBS WebSocket authentication + request/response |
| `obs-scene.ps1` | hub | One-time: creates Starting Soon scene in OBS |
| `obs-update-starting-soon.ps1` | hub | Rebuilds Starting Soon browser source |
| `obs-add-scene.ps1` | hub | One-time: adds BRB / End of Stream / Tech Difficulties scenes |
| `obs-setup.ps1` | hub | One-time: replaces StreamElements alerts with Twitch native alert box |
| `obs-optimize.ps1` | hub | One-time: configures OBS for 1080p60 |
| `obs-verify.ps1` | hub | Check OBS WebSocket connectivity |
| `obs-audit.ps1` | hub | Full OBS configuration audit |
| `obs-dbg.ps1` | hub | Raw WebSocket debug tool |
| `obs-test.ps1` | hub | Quick connectivity test |

## Twitch Integration

| File | Location | Purpose |
|------|----------|---------|
| `twitch-module.ps1` | hub | Twitch Helix API wrapper — OAuth, channel info, title/game, chat |
| `twitch-chat-daemon.ps1` | hub | Persistent IRC connection (SSL) — parses PRIVMSG + USERNOTICE |
| `twitch-credentials.enc` | hub | DPAPI-encrypted channel name, client ID, stream key |
| `twitch-token.enc` | hub | DPAPI-encrypted OAuth token (auto-refreshes) |

All secrets are encrypted with Windows DPAPI (tied to user account — zero configuration). Run `protect-twitch-secrets.ps1` to encrypt plaintext files, then delete the originals.

### Chat Overlay

`overlays/chat.html` — add as OBS Browser Source. Displays chat messages with:
- Username in the chatter's chat color
- Badges (sub, mod, VIP, broadcaster)
- Timestamps
- Fade-in animation for new messages
- Connection status indicator
- Most recent 15 messages visible

### Alert Overlay

`overlays/alerts.html` — add as OBS Browser Source. Displays queued alerts for:
- **Sub** / **Resub** — tier + cumulative months
- **Sub Gift** — gifter + recipient + tier
- **Raid** — raider + viewer count
- **Follow** — new follower (via ritual event)

Alerts are driven by USERNOTICE IRC messages parsed by `twitch-chat-daemon.ps1`. Each alert displays for 8 seconds with icon animation, then the next in queue.

## Background Daemons

When `go-live.ps1` runs, it starts these PowerShell background jobs:

| Job | Script | What it does |
|-----|--------|-------------|
| StreamMonitor | `obs-stream-monitor.ps1` | Polls OBS WebSocket every 2s — detects stream drops, auto-switches scenes |
| SpotifyPoller | `spotify-now-playing.ps1` | Reads Spotify window title, writes to `np-data.js` |
| AudioVis | `obs-audio-vis.ps1` | Reads OBS audio levels, writes to `audio-levels.js` |
| TwitchChat | `twitch-chat-daemon.ps1` | IRC connection — writes `chat-data.json` + `alerts-queue.json` |
| HotkeyDaemon | `obs-hotkeys.ps1` | Global hotkeys + AFK detection via Win32 P/Invoke |
| TimerSceneSwitch | inline | Waits N minutes, then auto-switches to Streaming scene |

All failed jobs are auto-restarted. Run `end-stream.ps1` to stop everything cleanly.

## Stream Summary

On `end-stream.ps1`, the summary displays:
- **Stream duration** — estimated from log timestamps
- **Chat messages** — total count from `chat-data.json`
- **Alert breakdown** — subs, resubs, gifts, raids, follows from `alerts-queue.json`
- **Jobs stopped** — how many background daemons were cleaned up

## Configuration

All shared settings in `Streaming/config.ps1`. Copy `config.ps1.example` → `config.ps1` and fill in secrets. The real `config.ps1` is gitignored.

| Variable | Default | What it controls |
|----------|---------|-----------------|
| `$OBS_Host` | `localhost` | OBS WebSocket host |
| `$OBS_Port` | `4455` | OBS WebSocket port |
| `$OBS_Password` | `"your-password"` | OBS WebSocket auth |
| `$Streaming_Root` | `$env:USERPROFILE\Streaming` | Root directory |
| `$Overlays_Dir` | `$Streaming_Root\overlays` | Browser source files |
| `$Monitor_PollIntervalMs` | `2000` | Stream monitor poll rate |
| `$Monitor_TechDiffTimeoutSec` | `60` | Wait before End of Stream |
| `$Spotify_PollIntervalSec` | `5` | Spotify title poll rate |
| `$Monitor_AudioVisIntervalMs` | `150` | Audio visualizer poll rate |
| `$Twitch_AlertBoxUrl` | *(twitch.tv URL)* | Twitch native alert box widget |
| `$LogRetentionMaxFiles` | `50` | Max log files before rotation |
| `$Hotkey_BRB` | `Ctrl+Shift+B` | Hotkey: Be Back Soon |
| `$Hotkey_Streaming` | `Ctrl+Shift+S` | Hotkey: Streaming |
| `$Hotkey_TechDiff` | `Ctrl+Shift+T` | Hotkey: Technical Difficulties |
| `$Hotkey_EndStream` | `Ctrl+Shift+E` | Hotkey: End of Stream |
| `$Hotkey_Mute` | `Ctrl+Shift+M` | Hotkey: Toggle Mic |
| `$Hotkey_Record` | `Ctrl+Shift+R` | Hotkey: Toggle Recording |
| `$Hotkey_PollIntervalMs` | `200` | Hotkey poll rate (ms) |
| `$AFK_TimeoutMinutes` | `5` | Idle time before auto-BRB |
| `$AFK_PollIntervalMs` | `3000` | Idle detection poll rate |
| `$Timer_SceneSwitchAuto` | `$true` | Auto-switch to Streaming after timer |

## Overlay Features

- **Shared theme**: `overlays/overlay-theme.css` — CSS custom properties, GPU-accelerated animations, `prefers-reduced-motion` support
- **Configurable timer**: `starting-soon.html?minutes=N` (default 5, max 120)
- **Now Playing**: Spotify track title displayed bottom-left via `np-data.js`
- **Audio Visualizer**: Rainbow spectrum bars driven by `audio-levels.js`
- **Chat overlay**: `chat.html` reads `chat-data.json` from IRC daemon
- **Alert overlay**: `alerts.html` reads `alerts-queue.json` for subs/raids/follows
- **Pride Month**: Subtle 6-stripe pride flag in bottom-right corner of every overlay; decorative line uses pride-inspired gradient (June 2026)
- **Auto crash handling**: Stream monitor detects drops → Technical Difficulties → auto-recover or End of Stream

## Stream Monitor State Machine

```
                    ┌── idle > 5 min (AFK) ──> BE BACK SOON
                    │
IDLE ──stream──> STREAMING ──stream drops──> TECH_DIFF
                    ^                            │
                    │                  ┌─────────┘
                    │                  │
               stream back     60s timeout
                    │                  │
                    └──────────────────┘
                                   END OF STREAM
```

- AFK detection: auto BRB after 5 min idle, back to Streaming on input
- Stream drop: auto Tech Difficulties, auto-recover or End of Stream after 60s
- Timer: auto switch from Starting Soon to Streaming after configurable minutes

## OBS Scene Collection

7 scenes in order:

1. **Starting Soon** — countdown overlay, now-playing slot, audio visualizer
2. **Streaming** — display capture, game/desktop content
3. **Just Chatting** — mic, Spotify, VM, PNGtuber
4. **Be Back Soon** — overlay (shutdown when hidden, reloads on show)
5. **Technical Difficulties** — overlay (shutdown when hidden, reloads on show)
6. **End of Stream** — overlay (shutdown when hidden, reloads on show)

Profile: `Discord_Capture` — 1920×1080 @ 60fps, AMF H.264 @ 6000 Kbps (Enhanced Broadcasting), 48kHz AAC, Twitch ingest

### Audio Routing
- **Desktop Audio** → live tracks only (1, 7, 8) — not on VOD track 2
- **Mic** → all tracks (commentary belongs in VOD)
- **Spotify** → all tracks except VOD track 2 (DMCA protection)
- **Window captures**: `capture_audio` disabled (Desktop Audio handles system audio — no phasing)

### Recording
MKV (advanced) / hybrid MP4 (fallback) — crash-safe format.

## Backup

```powershell
# Manual backup (keeps last 20 scene snapshots):
.\scripts\backup-obs-scenes.ps1

# Or hourly scheduled task:
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$env:USERPROFILE\Streaming\scripts\backup-obs-scenes.ps1`""
$trigger = New-ScheduledTaskTrigger -Daily -At 00:00 -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName "OBS Scene Backup" -Action $action -Trigger $trigger -Force
```

## Secrets Management

Credentials and OAuth tokens are encrypted with Windows DPAPI via `protect-twitch-secrets.ps1`:

```powershell
# Encrypt plaintext credentials:
.\scripts\protect-twitch-secrets.ps1

# Output: twitch-credentials.enc + twitch-token.enc
# Delete plaintext .json files after verification.
```

No plaintext secrets are stored on disk. Decryption is automatic — the `twitch-module.ps1` functions `Read-EncryptedJson` / `Write-EncryptedJson` handle both encrypted and plaintext fallback transparently.

## Version Control

Private repo at `https://github.com/NeotericGamer98/streaming`. Tracked in `Streaming/` directory, excluded:

- `config.ps1` (secrets) — use `config.ps1.example` as template
- `overlays/np-data.js`, `overlays/audio-levels.js` — generated overlay data
- `logs/`, `backups/` — runtime data
- `*.exe` — compiled PS2EXE binaries
- `Thumbs.db`, `.DS_Store`, `*.swp`, `*.swo`, `*~`, `.vscode/`, `.idea/`, `*.sublime-*`

See `CHANGELOG.md` for release history.
