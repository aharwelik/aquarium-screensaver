# Claude Code setup prompt

Copy everything below the `---` line into a fresh Claude Code conversation
inside this repo. Claude will install dependencies, build the binary, fetch
and transcode the video, prompt for permissions, and verify it works.

---

You are helping me set up the Aquarium screensaver in this repository. Walk
through these steps end-to-end, narrating briefly between each so I know what
you're doing.

1. **Sanity-check the platform.** Verify Apple Silicon (`uname -m` returns
   `arm64`) and macOS 13 or newer (`sw_vers -productVersion`). If either
   fails, stop and explain.

2. **Check the toolchain.** Confirm `swiftc` is available; if not, run
   `xcode-select --install` and tell me to re-run the prompt once it
   finishes.

3. **Install Homebrew packages if missing.** Run `command -v` checks for
   `ffmpeg`, `yt-dlp`, `aria2c`. Install each missing one with
   `brew install <pkg>`. Don't reinstall ones that are present.

4. **Compile the binary.** `swiftc -O Aquarium.swift -o bin/aquarium-bin`,
   `chmod +x bin/aquarium-bin bin/aquarium`.

5. **Symlink the CLI.** Try `ln -sf "$PWD/bin/aquarium" /usr/local/bin/aquarium`
   first. If `/usr/local/bin` isn't writable without sudo, fall back to
   `~/.local/bin/aquarium` and remind me to put it on my PATH.

6. **Fetch + transcode the video.** Only if `~/Library/Application Support/Aquarium/aquarium.mp4`
   doesn't already exist, run `./scripts/fetch-video.sh`. This takes 10-15
   minutes — keep me informed of progress via the script's output.

7. **Permissions.** Open the Input Monitoring System Settings pane:
   `open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"`.
   Tell me what to do once it's open (add `aquarium-bin` to the list and check
   the box). Wait for me to confirm before continuing.

8. **Smoke test.** Run `aquarium start 1` — a 1-minute show. After ~3 seconds,
   capture `screencapture -x /tmp/aq-1.png /tmp/aq-2.png /tmp/aq-3.png`,
   then read /tmp/aq-1.png to verify a fish tank is on screen.  After the
   1-minute show ends (or sooner if I move the mouse), the binary should
   exit cleanly. Confirm `pgrep aquarium-bin` is empty after.

9. **Recap.** Tell me what to type next:
   - `aquarium` — start a 15-minute show
   - `aquarium settings` — open the preferences window
   - `aquarium duration 30` — change the default duration

Style notes:
- Be brief. One sentence per step, not five.
- Don't claim a step succeeded that you didn't verify.
- If a step fails, *stop* and ask me what to do — don't power through.
