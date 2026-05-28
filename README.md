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
│   ├── backup-obs-scenes.ps1       (timestamped backups, keeps last 20)
│   ├── obs-audio-vis.ps1           (audio level overlay daemon)
│   └── start-stream-mode.ps1       (full stream mode launcher)
├── twitch/
│   └── README.md
├── logs/                           (auto-created — gitignored)
└── backups/                        (auto-created — gitignored)
```

## Quick Start

```powershell
# ONE command — starts stream monitor + Spotify + audio visualizer:
.\go-live.ps1

# Options:
.\go-live.ps1 -NoSpotify          # skip music poller
.\go-live.ps1 -NoAudioVis         # skip audio visualizer
.\go-live.ps1 -Minutes 15         # custom Starting Soon timer
```

Then go to OBS and hit "Start Streaming". The monitor auto-switches scenes.

## OBS Automation Hub

All automation scripts live at `.config/opencode/modules/obs/scripts/` and source `Streaming\config.ps1` for shared settings. Scripts in `Streaming/scripts/` are standalone launchers and daemons.

| Script | Location | Purpose |
|--------|----------|---------|
| `obs-preflight.ps1` / `.exe` | hub | Preflight — validates OBS config, scenes, audio, overlays, disk before go-live |
| `obs-stream-monitor.ps1` | hub | Daemon — polls OBS every 2s, auto-switches scenes |
| `go-live.ps1` | repo root | Launcher — starts monitor + Spotify + audio vis, handles restarts, logs output |
| `spotify-now-playing.ps1` | hub | Polls Spotify window title → writes `overlays/np-data.js` |
| `obs-audio-vis.ps1` | `repo/scripts/` | Daemon — writes audio levels to `overlays/audio-levels.js` |
| `start-stream-mode.ps1` | `repo/scripts/` | Launcher — full stream mode with all daemons |
| `obs-scene.ps1` | hub | One-time: creates Starting Soon scene in OBS |
| `obs-update-starting-soon.ps1` | hub | Rebuilds Starting Soon browser source |
| `obs-add-brb-endscene.ps1` | hub | One-time: adds BRB + End of Stream scenes |
| `obs-add-techdif-scene.ps1` | hub | One-time: adds Technical Difficulties scene |
| `obs-setup.ps1` | hub | One-time: replaces StreamElements alerts with Twitch native alert box |
| `obs-optimize.ps1` | hub | One-time: configures OBS for 1080p60 |
| `obs-verify.ps1` / `obs-verify2.ps1` | hub | Check OBS WebSocket connectivity |
| `obs-audit.ps1` | hub | Full OBS configuration audit |
| `obs-dbg.ps1` | hub | Raw WebSocket debug tool |
| `obs-test.ps1` | hub | Quick connectivity test |

## Twitch API Module

Located at `.config/opencode/modules/obs/twitch/`.

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

All shared settings live in `Streaming\config.ps1`. Copy `config.ps1.example` → `config.ps1` and fill in your OBS WebSocket password. The real `config.ps1` is gitignored.

| Variable | Default | What it controls |
|----------|---------|-----------------|
| `$OBS_Host` | `localhost` | OBS WebSocket host |
| `$OBS_Port` | `4455` | OBS WebSocket port |
| `$OBS_Password` | `"your-password"` | OBS WebSocket auth |
| `$Streaming_Root` | `$env:USERPROFILE\Streaming` | Root directory |
| `$Overlays_Dir` | `$Streaming_Root\overlays` | Browser source files |
| `$Assets_Dir` | `$Streaming_Root\assets` | Images, audio |
| `$Logs_Dir` | `$Streaming_Root\logs` | Runtime logs |
| `$Backups_Dir` | `$Streaming_Root\backups` | Scene backups |
| `$Scripts_Dir` | `$Streaming_Root\scripts` | Local scripts |
| `$Monitor_PollIntervalMs` | `2000` | Stream monitor poll rate |
| `$Monitor_TechDiffTimeoutSec` | `60` | Wait before End of Stream |
| `$Spotify_PollIntervalSec` | `5` | Spotify title poll rate |

## Overlay Features

- **Shared theme**: `overlays/overlay-theme.css` — CSS custom properties, GPU-accelerated animations, `prefers-reduced-motion` support
- **Configurable timer**: `starting-soon.html?minutes=N` (default 5, max 120)
- **Now Playing**: Spotify track title displayed bottom-left via `np-data.js`
- **Audio Visualizer**: Rainbow spectrum bars driven by `audio-levels.js`
- **Auto crash handling**: Stream monitor detects drops → Technical Difficulties → auto-recover or End of Stream

## Stream Monitor State Machine

```
IDLE ──stream starts──> STREAMING
STREAMING ──stream drops──> TECH_DIFF (auto-switch)
TECH_DIFF ──stream back──> STREAMING (auto-recover)
TECH_DIFF ──60s timeout──> END OF STREAM (final)
```

## OBS Scene Collection

6 scenes in order:

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

## Version Control

Private repo at `https://github.com/NeotericGamer98/streaming`. Tracked in `Streaming/` directory, excluded:

- `config.ps1` (secrets) — use `config.ps1.example` as template
- `overlays/np-data.js`, `overlays/audio-levels.js` — generated every 5s
- `logs/`, `backups/` — runtime data
- `*.exe` — compiled PS2EXE binaries
- `Thumbs.db`, `.DS_Store`, `*.swp`, `*.swo`, `*~`, `.vscode/`, `.idea/`, `*.sublime-*`

See `CHANGELOG.md` for release history.
