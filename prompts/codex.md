# Codex CLI setup prompt

For OpenAI Codex CLI users. From inside this repo:

```bash
codex
```

…then paste everything below the `---` line.

(If you've aliased Codex to `codex --dangerously-bypass-approvals-and-sandbox`,
the steps below will fly without prompting you for approval on each shell
call. That's fine — they're all read or build operations except the symlink
into `/usr/local/bin`, which is the one place to pay attention.)

---

Set up the Aquarium screensaver in this repository.

1. Verify Apple Silicon + macOS 13+:
   `[[ "$(uname -m)" == "arm64" ]] && (( $(sw_vers -productVersion | cut -d. -f1) >= 13 ))`
   If false, stop with a clear error.

2. Verify `swiftc`, `ffmpeg`, `yt-dlp`, `aria2c` are present. Install missing
   Homebrew formulas with `brew install`. If Homebrew itself is missing,
   abort and tell me to install it from brew.sh.

3. Build:
   ```bash
   swiftc -O Aquarium.swift -o bin/aquarium-bin
   chmod +x bin/aquarium-bin bin/aquarium
   ```

4. Symlink: `ln -sf "$PWD/bin/aquarium" /usr/local/bin/aquarium`
   (fallback to `~/.local/bin/aquarium` if that fails).

5. Fetch the video if it's missing:
   ```bash
   [[ -f "$HOME/Library/Application Support/Aquarium/aquarium.mp4" ]] || ./scripts/fetch-video.sh
   ```

6. Open the Input Monitoring pane so I can grant it:
   ```bash
   open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
   ```
   Pause here. Tell me to add `aquarium-bin` and check the box. Wait for my
   "done".

7. Smoke test:
   ```bash
   aquarium start 1                    # 1-minute show
   sleep 3 && screencapture -x /tmp/aq.png && qlmanage -p /tmp/aq.png
   ```

8. Final summary — what I should run next:
   - `aquarium` (15-min show)
   - `aquarium settings`
   - `aquarium duration 30`

Don't run the binary more than once. Don't move the mouse during the smoke
test — the global event monitor will dismiss the app immediately after the
5-second startup grace period.
