# NeoTheFox98 — Streaming Project

## Directory Structure

```
Streaming/                          ← git repo root
├── config.ps1.example              (copy to config.ps1, fill in secrets — gitignored)
├── config.ps1                      (your secrets — NOT committed)
├── go-live.ps1                     ← one-command launcher
├── .gitignore
├── .gitattributes
├── overlays/
│   ├── overlay-theme.css           (shared CSS vars, GPU accel, reduced-motion)
│   ├── starting-soon.html          (countdown via ?minutes=N, now-playing slot)
│   ├── brb.html
│   ├── end-of-stream.html
│   └── technical-difficulties.html
├── assets/
│   ├── Bean.png
│   ├── fox_neutral.png
│   ├── fox_talking.png
│   └── twitch-raid.mp3
├── scripts/
│   ├── README.md
│   └── backup-obs-scenes.ps1       (timestamped backups, keeps last 20)
├── twitch/
│   └── README.md
├── logs/                           (auto-created by go-live.ps1 — gitignored)
├── backups/                        (auto-created by backup script — gitignored)
└── README.md                       (this file)
```

## Quick Start

```powershell
# ONE command — starts stream monitor + optional Spotify poller, logs everything:
.\go-live.ps1

# Without Spotify:
.\go-live.ps1 -NoSpotify

# With custom Starting Soon timer:
.\go-live.ps1 -Minutes 15
```

Then go to OBS and hit "Start Streaming". The monitor auto-switches scenes.

## OBS Automation Scripts

Located at: `.config/opencode/modules/obs/scripts/`

All scripts source `Streaming\config.ps1` for shared settings (OBS host, port, password, paths).

| Script | Purpose |
|--------|---------|
| `obs-stream-monitor.ps1` | **Daemon** — polls OBS every 2s, auto-switches scenes (the workhorse) |
| `go-live.ps1` | **Launcher** — starts monitor + Spotify, handles restarts, logs to `logs/` |
| `spotify-now-playing.ps1` | Polls Spotify window title → writes `overlays/np-data.js` |
| `obs-scene.ps1` | One-time: creates "Starting Soon" scene in OBS via WebSocket |
| `obs-update-starting-soon.ps1` | Rebuilds "Starting Soon" browser source |
| `obs-add-brb-endscene.ps1` | One-time: adds "Be Back Soon" + "End of Stream" scenes to JSON |
| `obs-add-techdif-scene.ps1` | One-time: adds "Technical Difficulties" scene to JSON |
| `obs-setup.ps1` | One-time: replaces StreamElements alerts with Twitch native alert box |
| `obs-optimize.ps1` | One-time: configures OBS for 1080p60 @ 8000 Kbps |
| `obs-verify.ps1` / `obs-verify2.ps1` | Check OBS WebSocket connectivity |
| `obs-audit.ps1` | Full OBS configuration audit |
| `obs-dbg.ps1` | Raw WebSocket debug tool |
| `obs-test.ps1` | Quick connectivity test |

## Twitch API Module

Located at: `.config/opencode/modules/obs/twitch/`

| File | Purpose |
|------|---------|
| `twitch-module.ps1` | Twitch Helix API wrapper — OAuth, channel info, chat |
| `twitch-credentials.json` | Channel name, client ID, stream key |
| `twitch-token.json` | OAuth token (auto-refreshes) |

## Backup

```powershell
# Manual backup (keeps last 20 scene snapshots):
.\scripts\backup-obs-scenes.ps1
```

Or add a scheduled task to run it hourly:
```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$env:USERPROFILE\Streaming\scripts\backup-obs-scenes.ps1`""
$trigger = New-ScheduledTaskTrigger -Daily -At 00:00 -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName "OBS Scene Backup" -Action $action -Trigger $trigger -Force
```

## Configuration

All shared settings live in `Streaming\config.ps1`:

| Variable | Default | What it controls |
|----------|---------|-----------------|
| `$OBS_Host` | `localhost` | OBS WebSocket host |
| `$OBS_Port` | `4455` | OBS WebSocket port |
| `$OBS_Password` | `"your-password"` | OBS WebSocket auth |
| `$Monitor_PollIntervalMs` | `2000` | Stream monitor poll rate |
| `$Monitor_TechDiffTimeoutSec` | `60` | Wait before End of Stream |
| `$Spotify_PollIntervalSec` | `5` | Spotify title poll rate |

Copy `config.ps1.example` → `config.ps1` and set your password. The real `config.ps1` is gitignored.

## Overlay Features

- **Shared theme**: `overlays/overlay-theme.css` — CSS custom properties, GPU-accelerated animations, `prefers-reduced-motion` support
- **Configurable timer**: `starting-soon.html?minutes=N` (default 5, max 120)
- **Now Playing**: Run `go-live.ps1` (or `spotify-now-playing.ps1` standalone) to show current Spotify track in the overlay
- **Auto crash handling**: Stream monitor detects drops → "Technical Difficulties" → auto-recover or End of Stream

## Stream Monitor State Machine

```
IDLE ──stream starts──> STREAMING
STREAMING ──stream drops──> TECH_DIFF (auto-switch)
TECH_DIFF ──stream back──> STREAMING (auto-recover)
TECH_DIFF ──60s timeout──> END OF STREAM (final)
```

## OBS Scene Collection

6 scenes in order: Starting Soon → Streaming → Just Chatting → Be Back Soon → End of Stream → Technical Difficulties

Profile: `Discord_Capture` — 1920x1080 @ 60fps, AMF H.264 @ 8000 Kbps, Twitch ingest

## Version Control

This repo tracks everything in `Streaming/` except:
- `config.ps1` (secrets) — use `config.ps1.example` as a template
- `overlays/np-data.js` (generated every 5s)
- `logs/` and `backups/` (runtime data)
