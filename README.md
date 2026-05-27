# NeoTheFox98 — Streaming Project

## Directory Structure

```
Streaming/
├── overlays/          # HTML/CSS overlay files (OBS browser sources)
│   ├── overlay-theme.css
│   ├── starting-soon.html          (configurable countdown via ?minutes=N)
│   ├── brb.html                    (be right back screen)
│   ├── end-of-stream.html          (stream ended screen)
│   └── technical-difficulties.html (auto-shown on stream crash)
├── assets/            # Media files used by overlays and OBS
│   ├── Bean.png       (main avatar)
│   ├── fox_neutral.png
│   ├── fox_talking.png
│   └── twitch-raid.mp3
├── scripts/           → points to modules/obs/scripts/
├── twitch/            → points to modules/obs/twitch/
└── README.md          (this file)
```

## OBS Automation Scripts

Located at: `.config/opencode/modules/obs/scripts/`

| Script | Purpose |
|--------|---------|
| `obs-stream-monitor.ps1` | **Daemon** — polls OBS every 2s, auto-switches scenes on stream start/stop/crash |
| `obs-scene.ps1` | Creates the "Starting Soon" scene in OBS |
| `obs-update-starting-soon.ps1` | Rebuilds the "Starting Soon" browser source |
| `obs-setup.ps1` | Replaces StreamElements alerts with Twitch native alert box |
| `obs-optimize.ps1` | Configures OBS for 1080p60 @ 8000 Kbps |
| `obs-add-brb-endscene.ps1` | Adds "Be Back Soon" and "End of Stream" scenes |
| `obs-add-techdif-scene.ps1` | Adds "Technical Difficulties" scene |
| `obs-verify.ps1` / `obs-verify2.ps1` | Checks OBS WebSocket connectivity and config |
| `obs-audit.ps1` | Full OBS configuration audit |
| `obs-dbg.ps1` | Raw WebSocket debug tool |
| `obs-test.ps1` | Quick connectivity test |
| `spotify-now-playing.ps1` | Polls Spotify window title, writes `np-data.js` for overlay |

## Twitch API Module

Located at: `.config/opencode/modules/obs/twitch/`

| File | Purpose |
|------|---------|
| `twitch-module.ps1` | Twitch Helix API wrapper — OAuth, channel info, chat |
| `twitch-credentials.json` | Channel name, client ID, stream key |
| `twitch-token.json` | OAuth token (auto-refreshes) |

## Overlay Features

- **Shared theme**: `overlays/overlay-theme.css` — CSS custom properties, GPU-accelerated animations, `prefers-reduced-motion` support
- **Configurable timer**: `starting-soon.html?minutes=N` (default 5)
- **Now Playing**: Run `spotify-now-playing.ps1` to show current Spotify track in overlay
- **Auto crash handling**: Stream monitor detects drops → "Technical Difficulties" → auto-recover or End of Stream

## Stream Monitor State Machine

```
IDLE ──stream starts──> STREAMING
STREAMING ──stream drops──> TECH_DIFF (auto-switch)
TECH_DIFF ──stream back──> STREAMING (auto-recover)
TECH_DIFF ──60s timeout──> END OF STREAM
```

## OBS Scene Collection

6 scenes in order: Starting Soon → Streaming → Just Chatting → Be Back Soon → End of Stream → Technical Difficulties

Profile: `Discord_Capture` — 1920x1080 @ 60fps, AMF H.264 @ 8000 Kbps, Twitch ingest

## Quick Start

```powershell
# Before stream:
powershell -ExecutionPolicy Bypass -File ".config\opencode\modules\obs\scripts\obs-stream-monitor.ps1"

# Optional — show now playing in overlay (separate terminal):
powershell -ExecutionPolicy Bypass -File ".config\opencode\modules\obs\scripts\spotify-now-playing.ps1"
```
