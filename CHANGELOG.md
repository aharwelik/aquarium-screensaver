# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Native `.saver` bundle** (`saver/Aquarium.saver`).  Builds via
  `./saver/build.sh install` and drops into `~/Library/Screen Savers/`.
  Shows up in **System Settings → Wallpaper → Screen Saver** alongside
  every other Mac screensaver.  ScreenSaverEngine handles activation,
  multi-display, and dismissal-on-input natively — no LaunchAgent
  watchdog needed.  `ScreenSaverView` subclass hosts an `AVPlayerLayer`
  per display; video resolves from `Contents/Resources/aquarium.mp4`
  (symlinked at build time to the standalone install location so we
  don't duplicate 1.5 GB).  Audio is muted for the System Settings
  preview pane.  Tested via `[NSBundle loadAndReturnError]` —
  principal class `AquariumView` resolves cleanly.
- **Autostart**: `aquarium autostart on` now installs a per-user LaunchAgent
  (`com.harwelik.aquarium.autostart`) that polls `HIDIdleTime` from
  `IOHIDSystem` every 60 seconds. When idle ≥ `autostartThresholdSeconds`
  (default 3600) and Aquarium isn't already running, it launches the binary.
  Anthony walks away → fish tank appears; Anthony comes back → the binary's
  own global NSEvent monitor dismisses it.
- `aquarium threshold MIN` — adjust the idle threshold.
- `aquarium disable-mac-aerial` — opens System Settings → Wallpaper so you
  can flip Tahoe's "Show as Screensaver" off (the only way to stop
  `WallpaperAerialsExtension` from competing with Aquarium for the screen).

### Changed
- **Video file size: 3.6 GB → 1.5 GB** (58% reduction, visually identical, SSIM 0.986 / Y 0.982 / U 0.992 / V 0.994 between source and compressed).
  `scripts/fetch-video.sh` now runs a two-pass transcode: a fast
  VideoToolbox intermediate to drop the watermark, then a slow x265
  CRF24 pass that compresses ~38% tighter than VideoToolbox at the same
  visual quality. HDR10 metadata (BT.2020 + PQ + MaxCLL=1000 / MaxFALL=300
  + master-display primaries) is now explicitly preserved through the
  x265 params instead of relying on ffmpeg auto-propagation.
- New `AQUARIUM_QUICK=1` env flag on `fetch-video.sh` skips the slow x265
  pass for ~10-minute installs at 3.6 GB output — useful for CI / testing.

### Methodology
The compression target came out of a real benchmark: a 60-second slice
encoded four ways (VideoToolbox q60, VideoToolbox 8 Mbps, x265 slow
CRF22, x265 slow CRF24) measured for size + encode time + SSIM against
the source. CRF24 won the quality-per-byte race; CRF22 was slightly
higher quality but 30% larger. Numbers in commit message below.

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
