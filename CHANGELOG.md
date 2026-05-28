# Changelog

All notable changes to this project are documented here.

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

[0.1.2]: https://github.com/NeotericGamer98/streaming/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/NeotericGamer98/streaming/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/NeotericGamer98/streaming/releases/tag/v0.1.0
