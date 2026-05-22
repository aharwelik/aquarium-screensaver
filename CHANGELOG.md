# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-05-22

The first public release. Built by Anthony Harwelik in a single evening after
giving up on the May 2026 macOS aquarium-screensaver landscape.

### Added
- Single-file Swift app (`Aquarium.swift`) — borderless `NSWindow` per
  `NSScreen` at `kCGMaximumWindowLevel`, AVPlayer + AVPlayerLayer per window
  using the M-series hardware HEVC decoder.
- 15-minute default countdown that pauses while the screen is locked and
  resumes (restarting the timer) on unlock.
- Local + global NSEvent monitors covering keys, all mouse buttons, mouse
  movement, drags, and scroll — any input dismisses the show.
- 5-second startup grace period so synthetic activation events at launch
  don't terminate the app instantly.
- Deferred re-order pass at +50 ms / +250 ms / +1 s to defeat Tahoe's
  Window-Server demotion of screensaver-level windows on the active display.
- SwiftUI settings panel (`aquarium settings`): duration, audio mute /
  volume / output display, panscan vs letterbox, source video path, restore
  defaults.
- CLI wrapper (`bin/aquarium`): `start [MIN]`, `stop`, `status`, `settings`,
  `duration MIN`, `reset-defaults`, `version`, `help`.
- `install.sh` with Apple-Silicon + macOS 13+ check, Homebrew + ffmpeg +
  yt-dlp + aria2 install path, Xcode CLT detection, Input-Monitoring System
  Settings deep link.
- `scripts/fetch-video.sh` — downloads a 16-minute 4K60 HDR vp9.2 coral-reef
  slice via yt-dlp + aria2c (16 parallel chunks), re-encodes to HEVC main10
  with `hevc_videotoolbox`, applies a localized Gaussian blur to the source
  watermark (580×130 px rect, σ = 40) — rest of the 3840×2160 frame is
  pristine.
- Lock-aware playback control via `com.apple.screenIsLocked` /
  `com.apple.screenIsUnlocked` distributed notifications.
- `docs/screensaver-tuning.md` — workarounds for Tahoe's
  `WallpaperAerialsExtension` idle behavior that bypasses `caffeinate`.
- Repo scaffolding: MIT `LICENSE`, `.gitignore`, `README.md`,
  `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, GitHub Actions CI,
  issue + PR templates, `FUNDING.yml` for GitHub Sponsors.
- AI-assistant setup prompts under `prompts/` for Claude Code and Codex.

### Known limitations
- True "fish swim across displays" continuity isn't possible with stock
  video — would require a real-time renderer aware of global display
  geometry. Workaround: each display starts at a staggered offset
  (0 / 5 min / 10 min) so they don't look mirrored.
- VP9 source decode falls back to software on M1 / M1 Pro / M1 Max
  (Apple added VP9 hw decode only on M3+). The HEVC transcode is what
  enables hardware playback on all Apple-Silicon generations.
- Tahoe's `WallpaperAerialsExtension`-driven idle wallpaper engages
  independently of `caffeinate` and the legacy `idleTime` setting; users
  who want to disable it have to flip the "Show as screensaver" toggle in
  System Settings → Wallpaper.
