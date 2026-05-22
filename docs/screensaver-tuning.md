# macOS Screensaver Tuning Notes

Anthony Harwelik's preferred state for his M1 Max 3-display rig:

| Setting                                | Value         | Why                                  |
| -------------------------------------- | ------------- | ------------------------------------ |
| `com.apple.screensaver idleTime`       | **3600 s (1 hr)** | Default 30 min was too aggressive |
| `pmset displaysleep`                   | 65 min        | Display sleep slightly after saver   |
| `pmset sleep`                          | 0 (never)     | System never sleeps                  |
| `caffeinate -d -i -t 28800` (8 hr)     | running       | Belt + suspenders idle blocker       |

## Apply
```bash
defaults -currentHost write com.apple.screensaver idleTime -int 3600
killall cfprefsd
sudo pmset -a displaysleep 65
sudo pmset -a sleep 0
caffeinate -d -i -t 28800 &
```

## The Tahoe Aerials-as-idle trap

macOS Tahoe (26+) added a **second** screensaver pathway via `WallpaperAgent` +
`WallpaperAerialsExtension` that is *independent* of the legacy
`com.apple.screensaver` settings AND *bypasses* `caffeinate -d -i`.

To disable it: **System Settings → Wallpaper → turn off "Show as screensaver"**.
There is no clean `defaults` write that flips this without rewriting the
binary plist in `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`,
so the GUI toggle is the right path.

## Revert to factory defaults
```bash
defaults -currentHost delete com.apple.screensaver idleTime
sudo pmset -a displaysleep 10
sudo pmset -a sleep 1
pkill caffeinate
```
