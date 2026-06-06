# Changelog

All notable changes to this project are documented here.

## [0.2.1] — 2026-06-05

### Added
- `overlays/chat.html` — Twitch chat overlay for OBS Browser Source
- `overlays/alerts.html` — sub/raid/follow alert overlay with queue
- `end-stream.ps1` — graceful cleanup: stops 6 daemon types, stops recording, switches to End of Stream scene, removes transient data, shows stream summary
- `obs-hotkeys.ps1` — global hotkey daemon via Win32 P/Invoke (`GetAsyncKeyState`)
- AFK detection via `GetLastInputInfo` — auto-switch to BRB after 5 min idle
- Timer-driven auto scene switch — Starting Soon → Streaming after countdown
- Stream summary on end: duration, chat count, alert breakdown (subs/raids/follows)
- Re-entrancy guard in `go-live.ps1` — prevents duplicate daemon spawns
- Pre-flight Twitch credential validation before launching chat daemon

### Changed
- `go-live.ps1`: `-NoHotkeys`, `-Force` switches; hotkey daemon launch; timer scene switch job; all monitored in keepalive loop
- `end-stream.ps1`: reads `chat-data.json` + `alerts-queue.json` for summary analytics
- `twitch-chat-daemon.ps1`: parses USERNOTICE IRC messages (sub/resub/subgift/raid/ritual), writes `alerts-queue.json`
- `config.ps1`: 7 new variables for hotkey bindings, AFK timeout, timer auto-switch

### Hotkeys
| Combo | Action |
|-------|--------|
| Ctrl+Shift+B | Be Back Soon |
| Ctrl+Shift+S | Streaming |
| Ctrl+Shift+T | Technical Difficulties |
| Ctrl+Shift+E | End of Stream |
| Ctrl+Shift+M | Toggle Mic/Aux mute |
| Ctrl+Shift+R | Toggle Recording |

## [0.2.0] — 2026-06-05

### Added
- `obs-wsapi.psm1` — shared OBS WebSocket module (~400 lines, deduplicates auth + request/response)
- `protect-twitch-secrets.ps1` — DPAPI encryption for Twitch credentials and OAuth tokens
- `twitch-chat-daemon.ps1` — persistent Twitch IRC chat connection over SSL
- `obs-add-scene.ps1` — unified scene adder (replaces 2 duplicated scripts)
- `AUDIT-2026-06-05.md` — full root cause analysis of 14 findings

### Fixed
- **Security**: Hardcoded OBS WebSocket password + Twitch alert URL moved to `config.ps1`
- **Bug**: `$intervalMs` undefined in audio visualizer (CPU spin loop)
- **Bug**: Multi-frame truncation in stream monitor (StringBuilder loop)
- **Bug**: Profile name mismatch `Discord Capture` → `Discord_Capture`
- **Bug**: go-live uptime message showing delta instead of total elapsed
- **Config**: Added `$Monitor_AudioVisIntervalMs`, `$SceneCollectionName`, `$LogRetentionMaxFiles`
- **Missing**: Twitch ingest server validation, mic-on-VOD track check, log file rotation
- **Cleanup**: `obs-verify2.ps1` deleted, .gitignore redundant rule, `make-fox-avatar.py` path

### Changed
- Secrets stored as DPAPI-encrypted `.enc` files (plaintext `.json` fallback retained for compatibility)
- Scene adder unified via parameterized script (`-SceneName` + `-OverlayFile`)
- Stream monitor tracks frame drops (≥1% threshold) and reconnection count
- Chat daemon integrated into `go-live.ps1` with `-NoChat` switch

## [0.1.2] — 2026-05-27

### Added
- `scripts/obs-audio-vis.ps1` — audio level overlay daemon
- `scripts/start-stream-mode.ps1` — stream mode launcher
- `go-live.ps1`: `-NoAudioVis` switch, audio vis daemon launch + auto-restart
- `go-live.ps1`: window title fix (`$host.UI.RawUI.WindowTitle`)
- `.gitignore`: `overlays/audio-levels.js`, `*.exe` (PS2EXE binaries)
- `.gitattributes`: full file-type normalization (CRLF for scripts/web, binary for assets)

### Changed
- `go-live.ps1`: passes OBS config from `config.ps1` to sub-scripts instead of relying on their own sourcing

## [0.1.1] — 2026-05-27

### Added
- `obs-preflight.ps1` / `.exe` — 11-point preflight validator before go-live
- Overlay lifecycle settings: `shutdown: true` + `restart_when_active: true` for BRB, End, TechDiff scenes

### Changed
- OBS recording format: MP4 → MKV (Advanced) / hybrid MP4 (Simple) for crash safety
- Scene "PC Deskop Capture" → "Streaming" to match monitor script expectations
- Scene order: Starting Soon → Streaming → Just Chatting → BRB → Tech Diff → End of Stream
- Audio routing: Spotify and Virtual Machine mixers 255→253 (removed from VOD track 2 for DMCA)
- Window captures: `capture_audio: false` on Spotify/VM (Desktop Audio already handles system output)

## [0.1.0] — 2026-05-26

### Added
- Initial streaming stack: overlays, config, launcher, backup system
- `go-live.ps1` — one-command launcher with Spotify poller, stream monitor, auto-restart
- `scripts/backup-obs-scenes.ps1` — timestamped OBS scene backups (keeps last 20)
- `config.ps1.example` — template for secrets (actual config is gitignored)
- Overlays: starting-soon, brb, end-of-stream, technical-difficulties
- `overlays/overlay-theme.css` — shared CSS variables, GPU acceleration, reduced-motion
- Rainbow audio visualizer on Starting Soon overlay
- Now-playing display (bottom-left) via Spotify title polling
- OBS automation scripts (monitor, scene control, setup, optimize, audit, verify)
- Twitch API module (Helix, OAuth, channel info)
- README with directory structure, quick start, scripts table, audio routing docs

[0.2.1]: https://github.com/NeotericGamer98/streaming/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/NeotericGamer98/streaming/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/NeotericGamer98/streaming/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/NeotericGamer98/streaming/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/NeotericGamer98/streaming/releases/tag/v0.1.0
