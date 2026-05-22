# AquariumScreensaver

> A real coral-reef screensaver for Apple Silicon Macs.  4K HDR video, plays
> on every display, hardware-decoded, MIT-licensed, no ads, no telemetry.

Built by **Anthony Harwelik** because every "aquarium" on the Mac App Store is
either a paid generic GLSL fish or an ad-supported web wrapper, and the open
ones don't handle multiple displays cleanly. This one runs a curated 4K60 HDR
coral-reef clip at AVFoundation's screensaver window level — above the Dock,
above the menu bar, above whatever app you forgot you left open — and bails the
instant you touch the keyboard or mouse.

![Aquarium running on Anthony's three-monitor M1 Max rig](docs/screenshots/triple-display.jpg)

---

## Quick start

```bash
git clone https://github.com/aharwelik/aquarium-screensaver.git
cd aquarium-screensaver
./install.sh                 # ~10 min, mostly the video transcode
aquarium                     # start the show (default 15 min)
```

## What it actually does

1. Downloads the first 16 minutes of a real 4K60 HDR coral-reef clip from YouTube
   (vp9.2, BT.2020 + PQ).
2. Re-encodes it to HEVC main10 with Apple's `hevc_videotoolbox` hardware
   encoder, applying a localized Gaussian blur (`crop`→`gblur`→`overlay`) over
   the "Aura Video Art" watermark in the bottom-left corner.  Only 580×130
   pixels of the 3840×2160 frame are blurred — the rest is pristine.
3. Builds a Swift binary that:
   - Spawns one borderless `NSWindow` per `NSScreen`, parked at
     `.screenSaverWindow` level so it floats above every app and the menu bar.
   - Plays the file through an `AVPlayer` + `AVPlayerLayer` per window —
     AVFoundation auto-picks hardware HEVC decode + Metal compositing, so each
     stream sits at ~1-3 % CPU on an M1.
   - Watches `com.apple.screenIsLocked` / `…Unlocked` notifications so the
     15-minute timer only ticks while the screen is unlocked.  Locked the Mac
     before launch?  The show waits patiently for your password.
   - Installs **two** event monitors (`addLocalMonitorForEvents` +
     `addGlobalMonitorForEvents`) covering keys, all mouse buttons, scroll,
     mouse-move, and drag.  *Any* input exits the app — same guarantee as a
     real screensaver, no possibility of getting stuck.

## Hardware & software requirements

| Component                | Minimum                                              |
| ------------------------ | ---------------------------------------------------- |
| CPU                      | Apple Silicon (M1 / M2 / M3 / M4 family)             |
| GPU                      | Bundled Apple GPU — no discrete card needed          |
| RAM                      | 8 GB recommended                                     |
| Storage                  | ~5 GB free (24 GB temporarily during transcode)      |
| macOS                    | 13 Ventura or newer (tested through 26 Tahoe)        |
| Xcode CLT (`swiftc`)     | any current version                                  |
| Homebrew                 | for ffmpeg / yt-dlp / aria2                          |

The HEVC main10 decoder pipe is the reason this is Apple-Silicon only — Intel
Macs can run it via software decode but it'll burn CPU you don't want burned.

## Permissions

On first launch macOS will ask for **Input Monitoring** so the global event
monitor can hear ⌘-Tab / arrow keys / mouse moves regardless of which screen
they happen on.  `install.sh` opens the right System Settings pane for you.

No network, no telemetry, no analytics, no entitlements beyond what AppKit /
AVFoundation need.

## CLI reference

```
aquarium                        start the show (default 15 minutes)
aquarium start                  same as above
aquarium start 30               start with a custom duration in minutes
aquarium stop                   kill the running aquarium
aquarium status                 is it running?
aquarium settings               open the preferences window
aquarium duration 5             change the default to 5-minute shows
aquarium reset-defaults         factory-reset all settings
aquarium version                print version
aquarium help                   show usage
```

## Settings window

`aquarium settings` brings up a SwiftUI form with the options a normal
screensaver gives you, plus a couple Anthony added because his rig has an
ultrawide + a retina + a 1080p hooked up at the same time:

- Show length (1–120 min)
- Fill each screen by cropping  *vs* letterbox to original aspect
- Stagger between displays (0 → 10 min — fakes "different angles of the same
  tank" instead of mirroring three identical streams)
- Master mute, volume, and which display plays audio
- Source video path (point it at your own 4K clip if you'd rather)
- Restore Defaults

Settings live under the `com.harwelik.aquarium` `defaults` domain, so you can
also do this from the terminal:

```bash
defaults write com.harwelik.aquarium durationSeconds -float 1800
defaults read com.harwelik.aquarium
defaults delete com.harwelik.aquarium     # full reset
```

## CPU & memory footprint

Measured on Anthony's M1 Max during a 3-display run (Sceptre 3440×1440 +
MacBook 16" XDR + HP 1080p):

| Metric                | Value                          |
| --------------------- | ------------------------------ |
| CPU (steady state)    | 4-8 % total across all streams |
| RSS                   | ~110 MB                        |
| Energy impact         | Low                            |
| Quit-to-clean         | < 50 ms (all AVPlayers paused, items dropped, monitors removed) |

`Aquarium.swift` releases AVPlayer items on `applicationWillTerminate`, so
ARC + AVFoundation release the IOSurface / Metal textures immediately — no
lingering GPU work after dismissal.

## File layout

```
aquarium-screensaver/
├── Aquarium.swift           # single-file Swift app (player + settings + CLI)
├── install.sh               # platform check, deps, build, video fetch
├── uninstall.sh             # clean removal
├── LICENSE                  # MIT, Anthony Harwelik 2026
├── .gitignore
├── bin/
│   └── aquarium             # CLI wrapper (start/stop/status/settings/duration)
├── scripts/
│   └── fetch-video.sh       # download + transcode + watermark blur pipeline
└── docs/
    └── screenshots/
```

## Troubleshooting

**"Aquarium video not found" dialog on launch**
The fetch step didn't run or didn't finish.  Re-run:
```bash
./scripts/fetch-video.sh
```

**The fish tank shows up but the menu bar is still visible on one display**
Apple's window-server treats fullscreen as per-Space; the `.screenSaverWindow`
level avoids that, but if Mission Control is mid-animation when you launch,
the level can be demoted.  Just `aquarium stop && aquarium start` once
animations have settled.

**Input doesn't dismiss the app**
Grant Input Monitoring to the binary (or to your terminal, if you're invoking
it from `zsh`).  `install.sh` opens the right pane for you.

**It locked my Mac during the transcode**
Run the transcode under `caffeinate -d -i -t 1800` to keep the system awake.
The shipped `fetch-video.sh` does this automatically when invoked through
`install.sh`.

## Contributing

This is Anthony's personal scratch-itch, but PRs are welcome.  Things that
would be especially nice:

- A real Swift-based real-time aquarium simulator that knows the global display
  geometry, so fish can actually swim from one monitor to the next (no public
  open-source implementation of this exists on Mac in 2026).
- An app-bundle (`.app`) build so users can drop it in `/Applications` instead
  of running from a source checkout.
- A native `.saver` bundle so System Settings → Screen Saver can pick it up.

## License

MIT.  See `LICENSE`.  Anthony Harwelik, 2026.
