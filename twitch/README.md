# Twitch API Module & Chat Daemon

Files live at `.config\opencode\modules\obs\twitch\`

| File | Purpose |
|------|---------|
| `twitch-module.ps1` | Helix API wrapper — OAuth, channel info, title/game, chat commands |
| `twitch-chat-daemon.ps1` | Persistent IRC daemon (SSL) — writes `chat-data.json` + `alerts-queue.json` |
| `twitch-credentials.enc` | DPAPI-encrypted channel name, client ID, stream key |
| `twitch-token.enc` | DPAPI-encrypted OAuth token |

The IRC daemon parses PRIVMSG (chat messages) and USERNOTICE (subs, raids, etc.).
Two overlays consume its output:
- `overlays/chat.html` — scrollable chat display
- `overlays/alerts.html` — sub/raid/follow alert queue

See `Streaming\README.md` for full documentation.
