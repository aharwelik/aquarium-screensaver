# Generic AI-agent setup prompt

For any coding agent that can run shell commands inside this repository.
Paste verbatim below the `---`.

---

Set up the Aquarium screensaver in this repository.

Prerequisites to verify:
- `uname -m` returns `arm64` (Apple Silicon required)
- `sw_vers -productVersion` major version ≥ 13 (Ventura or newer)
- `swiftc`, `brew`, `ffmpeg`, `yt-dlp`, `aria2c` all on PATH — install
  missing ones via Homebrew.

Build:
```bash
swiftc -O Aquarium.swift -o bin/aquarium-bin
chmod +x bin/aquarium-bin bin/aquarium
ln -sf "$PWD/bin/aquarium" /usr/local/bin/aquarium  # or ~/.local/bin
```

Fetch video if absent:
```bash
[[ -f "$HOME/Library/Application Support/Aquarium/aquarium.mp4" ]] \
  || ./scripts/fetch-video.sh
```

Open Input Monitoring System Settings pane and pause for the user to flip
the toggle:
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
```

Smoke test (1-minute show, screenshot at 3s, exits on input or after 60s):
```bash
aquarium start 1
sleep 3
screencapture -x /tmp/aq-1.png /tmp/aq-2.png /tmp/aq-3.png
```

Final guidance to the user:
- `aquarium` — start a 15-minute show
- `aquarium settings` — preferences window
- `aquarium duration 30` — change default duration
- `aquarium stop` — kill running instance
- `aquarium reset-defaults` — factory reset

Rules:
- Don't run the binary more than once.
- If any step fails, stop and report — don't proceed past a failure.
- Don't claim a step succeeded without verifying it.
