#!/usr/bin/env zsh
# ----------------------------------------------------------------------------
#  saver/build.sh — build Aquarium.saver bundle and (optionally) install it.
#  Author: Anthony Harwelik <aharwelik@gmail.com>
#
#  What it does:
#    1.  Compiles saver/AquariumView.swift as a loadable Swift/Cocoa bundle
#        (`-emit-library -Xlinker -bundle`) against ScreenSaver +
#        AVFoundation + AVKit + Cocoa.
#    2.  Assembles Aquarium.saver/ with Contents/MacOS/Aquarium and
#        Contents/Info.plist.
#    3.  Embeds the canonical video from ~/Library/Application Support/Aquarium/
#        into the bundle's Resources/ via APFS clone (cp -c).  It MUST be a
#        real file, NOT a symlink: the sandboxed screensaver host on Sonoma/
#        Tahoe cannot read a symlink that points outside the bundle (that bug
#        renders the saver as a black screen).
#    4.  If invoked with `install`, copies the bundle into
#        ~/Library/Screen Savers/ and opens the Screen Saver pref pane.
#
#  Usage:
#      ./saver/build.sh                # build only, into saver/build/
#      ./saver/build.sh install        # build + install + open prefs
# ----------------------------------------------------------------------------

set -e

HERE="${0:A:h}"
REPO_ROOT="${HERE:h}"
BUILD_DIR="$HERE/build"
BUNDLE="$BUILD_DIR/Aquarium.saver"
INSTALL_DIR="$HOME/Library/Screen Savers"
VIDEO_PATH="$HOME/Library/Application Support/Aquarium/aquarium.mp4"

print -P "%F{cyan}==>%f cleaning + scaffolding bundle"
rm -rf "$BUILD_DIR"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

print -P "%F{cyan}==>%f compiling AquariumView.swift as a Cocoa bundle"
# -emit-library + -bundle produces a loadable .bundle Mach-O suitable for
# `[NSBundle loadAndReturnError]`.  We deliberately do NOT use @executable_path —
# the bundle gets loaded into ScreenSaverEngine's process.
swiftc -O \
    -emit-library -Xlinker -bundle \
    -module-name Aquarium \
    -framework Cocoa \
    -framework ScreenSaver \
    -framework AVKit \
    -framework AVFoundation \
    -o "$BUNDLE/Contents/MacOS/Aquarium" \
    "$HERE/AquariumView.swift"

print -P "%F{cyan}==>%f writing Info.plist"
cp "$HERE/Info.plist" "$BUNDLE/Contents/Info.plist"

print -P "%F{cyan}==>%f embedding video into Resources/"
# IMPORTANT: copy (APFS clone) the real file into the bundle — do NOT symlink.
# On macOS Sonoma/Tahoe the screensaver runs in a sandbox that cannot follow a
# symlink out to ~/Library/Application Support, so a symlinked video renders as
# a black screen.  `cp -c` clones via APFS (instant, block-shared, ~no extra
# disk) while leaving a real, sandbox-readable file inside the bundle.
if [[ -f "$VIDEO_PATH" ]]; then
  rm -f "$BUNDLE/Contents/Resources/aquarium.mp4"
  cp -c "$VIDEO_PATH" "$BUNDLE/Contents/Resources/aquarium.mp4" 2>/dev/null \
    || cp "$VIDEO_PATH" "$BUNDLE/Contents/Resources/aquarium.mp4"
else
  print -P "%F{yellow}!!%f video missing at $VIDEO_PATH — run ./install.sh first"
  print -P "%F{yellow}!!%f Bundle will still build, but it will be black until the video exists."
fi

# Sign ad-hoc so macOS gatekeeper doesn't refuse to load the bundle.
print -P "%F{cyan}==>%f ad-hoc codesign"
codesign --force --sign - --deep "$BUNDLE" 2>&1 | tail -3

print -P "%F{green}✓%f built $BUNDLE ($(du -sh $BUNDLE | awk '{print $1}'))"

if [[ "${1:-}" == "install" ]]; then
  print -P "%F{cyan}==>%f installing to $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  # Replace any existing installed copy
  rm -rf "$INSTALL_DIR/Aquarium.saver"
  cp -R "$BUNDLE" "$INSTALL_DIR/Aquarium.saver"

  # Open the right System Settings pane on Tahoe (Wallpaper) and Ventura/Sonoma
  # (Screen Saver) — different URLs depending on macOS version.
  print -P "%F{cyan}==>%f opening System Settings → Screen Saver"
  open "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension" 2>/dev/null \
    || open "x-apple.systempreferences:com.apple.WallpaperPrefPane" 2>/dev/null \
    || open "/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane" 2>/dev/null \
    || true

  print -P "%F{green}✓%f installed.  Look for 'Aquarium' in the Other / Custom screensavers list."
fi
