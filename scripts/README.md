# OBS Automation Scripts

Scripts live at `.config\opencode\modules\obs\scripts\`

| Script | Purpose |
|--------|---------|
| `obs-wsapi.psm1` | Shared OBS WebSocket module (auth + request/response) |
| `obs-preflight.ps1` | Pre-flight config validator |
| `obs-stream-monitor.ps1` | Daemon — polls OBS, auto-switches scenes |
| `obs-hotkeys.ps1` | Daemon — global hotkeys + AFK detection |
| `spotify-now-playing.ps1` | Spotify title poller |
| `obs-scene.ps1` | Create Starting Soon scene |
| `obs-update-starting-soon.ps1` | Rebuild Starting Soon browser source |
| `obs-add-scene.ps1` | Add BRB / End / TechDiff scene |
| `obs-setup.ps1` | Install Twitch alert box |
| `obs-optimize.ps1` | Configure 1080p60 |
| `obs-verify.ps1` | WebSocket connectivity test |
| `obs-audit.ps1` | Full config audit |
| `obs-dbg.ps1` | Raw WebSocket debug |
| `obs-test.ps1` | Quick connectivity test |

See `Streaming\README.md` for full documentation.
