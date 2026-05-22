# Permissions — what Aquarium asks for and why

Aquarium asks for **as little as possible** to work. This page walks through
each permission it touches, why it needs it, and how to grant or revoke it.

If you're a Mac security / Intune admin evaluating this for a managed fleet,
the short answer is: there are no entitlements beyond what AppKit and
AVFoundation use, no network at runtime, and no daemons.

## 1. Input Monitoring (the only "ask")

**System Settings → Privacy & Security → Input Monitoring**

### What it lets Aquarium do

Listen for keyboard, mouse, and trackpad events **globally** — i.e. even
when the fish-tank windows aren't the focused app — so the app can dismiss
itself the moment you touch the keyboard or move the mouse.

Without this permission, `addGlobalMonitorForEvents` returns events only when
the user's already clicking inside an Aquarium window, which would mean you'd
have to first click on a fish-tank window before the dismissal worked. Real
screensavers don't behave that way.

### What it does *not* let Aquarium do

- Aquarium does **not** record what keys you press. Look at
  `Aquarium.swift:installInputMonitors()` — the only thing the handlers do
  is call `NSApp.terminate(nil)`. There is no event payload inspection, no
  logging, no transmission.
- Aquarium does **not** simulate keys or mouse clicks. The Input Monitoring
  permission is *read-only*; you'd need Accessibility (which we never ask
  for) to synthesize input.

### How to grant

`install.sh` opens this pane for you. Manually:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
```

Then drag `/usr/local/bin/aquarium` (or wherever `install.sh` symlinked it)
into the list and check the box.

### How to revoke

Same pane, uncheck the box. The app still works, just doesn't dismiss
globally — you'd have to click an Aquarium window first.

## 2. Screen Recording (only if you want screenshots)

**System Settings → Privacy & Security → Screen Recording**

Aquarium itself **never** asks for Screen Recording. The reason it shows up
in this doc at all is that the `install.sh` developer-facing path uses
`screencapture` to verify the windows painted correctly across all your
displays. If you're not contributing code, you can ignore this entirely.

## 3. Files & Folders

Aquarium reads:

- `~/Library/Application Support/Aquarium/aquarium.mp4` — the video.
- `~/Library/Preferences/com.harwelik.aquarium.plist` — your settings.

That's it. Aquarium **never writes to** `~/Documents`, `~/Desktop`, your
iCloud Drive, your cloud-managed mailbox, or anything else.

## 4. Network

Zero, at runtime.

The only network connections in the entire project are made by `yt-dlp`
+ `aria2c` during the *one-time install* video fetch, going to YouTube's
CDN. If your environment blocks that, swap in your own 4K HDR video via the
settings panel (`aquarium settings → Source`) — the app will use whatever
you point it at.

## 5. No Apple privacy entitlements requested

- Camera: no
- Microphone: no
- Photos / Calendar / Contacts / Reminders: no
- Location: no
- Bluetooth: no
- Full Disk Access: no
- Accessibility: no
- Automation: no

## For managed-fleet admins (Intune / Jamf / Kandji)

This binary is unsigned and unnotarized for v1.0.0 — `install.sh` builds it
locally with `swiftc -O` on each machine. If you're rolling it out to a
fleet:

- The binary lives at `/usr/local/bin/aquarium-bin` (or
  `~/.local/bin/aquarium-bin` if `/usr/local` isn't writable).
- Pre-grant Input Monitoring via a PPPC payload — bundle identifier is
  `com.harwelik.aquarium` (set programmatically; the binary has no Info.plist
  bundle ID since it isn't a `.app`, so the system uses the executable path
  as identity).
- The video file is ~3.6 GB — pre-stage to `~/Library/Application Support/Aquarium/`
  if you want to skip the `yt-dlp` fetch on each endpoint.
- There is no LaunchAgent or LaunchDaemon. The app only runs when a user
  invokes `aquarium`.

Drop me a note via [bluetechgreen.com/contact](https://bluetechgreen.com/contact)
if you need a notarized version for your enterprise — Anthony does this kind
of compliant-Mac work day-to-day and can build you one against your specific
controls.
