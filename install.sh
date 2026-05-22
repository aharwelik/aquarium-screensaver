#!/usr/bin/env zsh
# ----------------------------------------------------------------------------
#  install.sh — one-shot installer for AquariumScreensaver.
#  Author: Anthony Harwelik <aharwelik@gmail.com>
#
#  What this does:
#    1.  Verifies you're on Apple Silicon + macOS 13+.
#    2.  Checks for Xcode Command Line Tools (needed for swiftc).
#    3.  Checks for Homebrew, ffmpeg, yt-dlp, aria2 — installs anything missing.
#    4.  Builds the Swift binary into ./bin/aquarium-bin.
#    5.  Symlinks the CLI wrapper into /usr/local/bin/aquarium (or your
#        ~/.local/bin if /usr/local isn't writable without sudo).
#    6.  Fetches and prepares the video (downloads + blurs watermark + installs
#        to ~/Library/Application Support/Aquarium/).
#    7.  If macOS hasn't granted the binary Screen Recording / Input Monitoring
#        permission yet, opens the right System Settings pane and pauses for
#        you to flip the toggle.
#
#  Designed to be re-runnable without harm.  Re-running just verifies state.
#
#  Run me:
#      ./install.sh
# ----------------------------------------------------------------------------

set -e
HERE="${0:A:h}"
APP_NAME="aquarium"
APP_BIN_NAME="aquarium-bin"
SRC_SWIFT="$HERE/Aquarium.swift"
OUT_BIN="$HERE/bin/$APP_BIN_NAME"
WRAPPER_BIN="$HERE/bin/$APP_NAME"
SUPPORT_DIR="$HOME/Library/Application Support/Aquarium"

red()    { print -P "%F{red}$*%f"; }
green()  { print -P "%F{green}$*%f"; }
yellow() { print -P "%F{yellow}$*%f"; }
blue()   { print -P "%F{cyan}$*%f"; }

step() { blue "==> $*"; }
fail() { red "✗ $*"; exit 1; }
ok()   { green "✓ $*"; }

# -- 1. Apple Silicon + macOS 13+ check -------------------------------------
step "Checking platform"
ARCH=$(uname -m)
[[ "$ARCH" == "arm64" ]] || fail "Apple Silicon required (you have $ARCH).  Anthony designed this for the M-series hardware HEVC decoder."
MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
(( MACOS_MAJOR >= 13 )) || fail "macOS 13 (Ventura) or newer required (you have $(sw_vers -productVersion))"
ok "macOS $(sw_vers -productVersion) on $ARCH"

# -- 2. Xcode CLT (swiftc) ---------------------------------------------------
step "Checking Xcode Command Line Tools"
if ! command -v swiftc >/dev/null 2>&1; then
  yellow "swiftc not found.  Installing Xcode Command Line Tools (will pop a dialog)…"
  xcode-select --install || true
  fail "After the install dialog finishes, re-run ./install.sh"
fi
ok "swiftc found ($(swiftc --version | head -1))"

# -- 3. Homebrew + helpers ---------------------------------------------------
step "Checking Homebrew + helpers"
if ! command -v brew >/dev/null 2>&1; then
  yellow "Homebrew not found.  Anthony's installer needs it for ffmpeg/yt-dlp/aria2."
  yellow "Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  fail "Install Homebrew, then re-run ./install.sh"
fi
for pkg in ffmpeg yt-dlp aria2; do
  if ! command -v "$pkg" >/dev/null 2>&1 && ! brew list "$pkg" >/dev/null 2>&1; then
    step "Installing $pkg via Homebrew"
    brew install "$pkg"
  fi
done
ok "ffmpeg, yt-dlp, aria2 ready"

# -- 4. Build the Swift binary ----------------------------------------------
step "Compiling Aquarium.swift (-O)"
mkdir -p "$HERE/bin"
swiftc -O "$SRC_SWIFT" -o "$OUT_BIN"
chmod +x "$OUT_BIN" "$WRAPPER_BIN"
ok "built $OUT_BIN ($(ls -lh $OUT_BIN | awk '{print $5}'))"

# -- 5. Symlink the wrapper into PATH ---------------------------------------
step "Symlinking CLI into PATH"
TARGET_DIR="/usr/local/bin"
if [[ ! -w "$TARGET_DIR" ]]; then
  TARGET_DIR="$HOME/.local/bin"
  mkdir -p "$TARGET_DIR"
  yellow "/usr/local/bin not writable — installing to $TARGET_DIR instead."
  yellow "  Make sure $TARGET_DIR is on your PATH (add to ~/.zshrc if needed):"
  yellow "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
ln -sf "$WRAPPER_BIN" "$TARGET_DIR/$APP_NAME"
ok "symlinked: $TARGET_DIR/$APP_NAME → $WRAPPER_BIN"

# -- 6. Fetch + prep the video ----------------------------------------------
mkdir -p "$SUPPORT_DIR"
if [[ -f "$SUPPORT_DIR/aquarium.mp4" ]]; then
  ok "video already installed at $SUPPORT_DIR/aquarium.mp4 (skipping)"
else
  step "Fetching + transcoding video (downloads 4K60 HDR, blurs watermark, ~10 min on M1 Max)"
  "$HERE/scripts/fetch-video.sh"
fi

# -- 7. Permission prompts ---------------------------------------------------
step "Checking macOS permissions"
# The global event monitor in Aquarium.swift needs Input Monitoring.  AVPlayer
# *technically* doesn't need Screen Recording, but if a user has set up a
# kiosk-style setup with extra screens they may need it for the screen-saver
# level windows to actually paint above secured panes.  We open both panes and
# let Anthony decide.
yellow "If Aquarium can't dismiss itself on input later, grant Input Monitoring to your terminal here."
yellow "Press <return> to open System Settings → Privacy & Security → Input Monitoring,"
yellow "or Ctrl-C if you've already done this."
read -r _
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" 2>/dev/null || \
  open "/System/Library/PreferencePanes/Security.prefPane" || true

# -- done --------------------------------------------------------------------
print
green "✓ Aquarium installed."
print
print "Try it out:"
print "    $APP_NAME              # run the 15-minute show"
print "    $APP_NAME start 5      # run for 5 minutes"
print "    $APP_NAME settings     # open the preferences window"
print "    $APP_NAME help         # see everything"
print
print "Anthony hopes you enjoy the fish."
