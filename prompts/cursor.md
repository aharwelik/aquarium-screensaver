# Cursor setup prompt

Open this repo in Cursor, then switch to **Agent** mode (`⌘ I`) and paste
the block below.

---

This is the Aquarium screensaver project. Please set it up on this Mac end
to end. Constraints:

- Apple Silicon + macOS 13+ only — bail early with a clear message if not.
- Use the Bash tool for all shell work; don't suggest commands for me to
  run manually unless I need to flip a UI toggle.
- Don't run the compiled binary more than once.

Steps:

1. Check platform: `uname -m` and `sw_vers -productVersion`.
2. Make sure `swiftc`, `brew`, `ffmpeg`, `yt-dlp`, `aria2c` are installed.
3. Build: `swiftc -O Aquarium.swift -o bin/aquarium-bin && chmod +x bin/aquarium-bin bin/aquarium`.
4. Symlink: `ln -sf "$PWD/bin/aquarium" /usr/local/bin/aquarium` (or
   `~/.local/bin/aquarium` if not writable).
5. Fetch the video if missing: `./scripts/fetch-video.sh`.
6. Open the Input Monitoring pane:
   `open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"`.
   Wait for me to confirm I added `aquarium-bin` to the allow list.
7. Smoke test: `aquarium start 1`, sleep 3, screenshot, read the screenshot
   back to confirm fish are on screen, wait for the show to end (or the
   global input monitor to dismiss it).
8. Tell me how to invoke it from here on: `aquarium`, `aquarium settings`,
   `aquarium duration 30`.

End with a 3-line summary: what's installed, where the binary lives, how to
launch it.
