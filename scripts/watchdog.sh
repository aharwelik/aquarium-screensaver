#!/usr/bin/env zsh
# ----------------------------------------------------------------------------
#  watchdog.sh — Aquarium autostart guard.
#  Author: Anthony Harwelik <aharwelik@gmail.com>
#
#  Invoked every minute by ~/Library/LaunchAgents/com.harwelik.aquarium.autostart.plist
#  while Anthony is signed in.  Reads the system-wide HIDIdleTime (the same
#  thing the OS uses to fire screensavers) and launches aquarium-bin when
#  the user has been idle longer than the configured threshold.
#
#  Dismissal is *not* this script's job — the binary watches NSEvent input
#  globally and quits itself the moment Anthony touches anything.
#
#  Tunables:
#    com.harwelik.aquarium autostartThresholdSeconds  (default 3600 = 60 min)
#    com.harwelik.aquarium autostartBinaryPath        (default: bundled bin)
#
#  Inspect / change from the terminal:
#    defaults write com.harwelik.aquarium autostartThresholdSeconds -int 1800
#    defaults read  com.harwelik.aquarium autostartThresholdSeconds
# ----------------------------------------------------------------------------

set -e

THRESHOLD=$(defaults read com.harwelik.aquarium autostartThresholdSeconds 2>/dev/null || echo 3600)
BIN=$(defaults read com.harwelik.aquarium autostartBinaryPath 2>/dev/null || echo "")
[[ -z "$BIN" ]] && BIN="$HOME/Projects/aquarium-screensaver/bin/aquarium-bin"

# Bail if the binary isn't where we expect it (e.g., uninstalled).
[[ -x "$BIN" ]] || { echo "watchdog: binary missing at $BIN" >&2; exit 0; }

# Bail if aquarium is already running — we never want to double-launch.
if pgrep -x aquarium-bin >/dev/null 2>&1; then
  exit 0
fi

# Read the system-wide HID idle counter (nanoseconds), convert to seconds.
# This is the exact value the OS itself uses to decide whether to fire a
# screensaver or display sleep — so we get the same signal from one place.
IDLE_NS=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $4; exit}' | tr -d '"')
[[ -z "$IDLE_NS" ]] && exit 0
IDLE_SEC=$((IDLE_NS / 1000000000))

# Launch when we've crossed the threshold.  The binary is detached so this
# script can return quickly; LaunchAgent's StartInterval will keep ticking.
if (( IDLE_SEC >= THRESHOLD )); then
  echo "$(date '+%F %T') idle ${IDLE_SEC}s ≥ ${THRESHOLD}s — launching aquarium"
  nohup "$BIN" > /tmp/aquarium-autostart.log 2>&1 &
  disown $! 2>/dev/null
fi
