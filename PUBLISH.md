# Publish the PRISM now-playing widget to GitHub Pages (LibreWolf-friendly)

This folder already contains `index.html` (the widget, ready to serve).
Pick ONE of the two routes below. Both open GitHub in LibreWolf for you to log
in — you keep control of your own credentials.

--------------------------------------------------------------------
## Route A — GitHub CLI (fastest, ~2 min)  [recommended if you have `gh`]
--------------------------------------------------------------------
Open a terminal (PowerShell or Git Bash) IN THIS FOLDER, then run:

    gh auth login            # opens LibreWolf to log in (first time only)
    git init
    git add index.html
    git commit -m "PRISM now-playing widget"
    gh repo create stream-overlays --public --source=. --push

Then enable Pages:

    gh api -X POST repos/:owner/stream-overlays/pages -f build_type=legacy -f "source[branch]=main" -f "source[path]=/"

Your URL will be:  https://<your-username>.github.io/stream-overlays/

--------------------------------------------------------------------
## Route B — plain git + GitHub website (no gh CLI)
--------------------------------------------------------------------
1. In LibreWolf, go to https://github.com/new
   - Repository name: stream-overlays
   - Public → Create repository (leave it empty, no README)

2. Terminal IN THIS FOLDER (use YOUR username where shown):

    git init
    git add index.html
    git commit -m "PRISM now-playing widget"
    git branch -M main
    git remote add origin https://github.com/<your-username>/stream-overlays.git
    git push -u origin main

   (Git will prompt you to authenticate in LibreWolf / with a token.)

3. On the repo page: Settings → Pages → Source: "Deploy from a branch" →
   Branch: main / (root) → Save. Wait ~1 minute.

Your URL will be:  https://<your-username>.github.io/stream-overlays/

--------------------------------------------------------------------
## After publishing (same for both routes)
--------------------------------------------------------------------
1. Open the URL above in LibreWolf to confirm the widget loads (it will show
   the "Connect Spotify" card and print the exact Redirect URI to register).

2. https://developer.spotify.com/dashboard → your app → Settings →
   Redirect URIs → add that EXACT URL → Save.

3. In OBS: add a Browser Source pointing at the URL (~460×110).
   Right-click the source → Interact → click Connect → log in to Spotify.
   (Do this inside OBS, not in LibreWolf — OBS has its own separate storage.)

Done. The card now shows your track over any scene, permanently.

Tip: to host the full scenes too later, just drop their .html files into this
same repo and point OBS at their URLs — same origin, no extra Spotify setup.
