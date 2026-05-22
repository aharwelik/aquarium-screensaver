#!/usr/bin/env zsh
# ----------------------------------------------------------------------------
#  uninstall.sh — remove AquariumScreensaver cleanly.
#  Author: Anthony Harwelik <aharwelik@gmail.com>
#
#  Leaves no residue:
#    - Removes the /usr/local/bin/aquarium (or ~/.local/bin) symlink
#    - Deletes the compiled binary in ./bin
#    - Deletes the video at ~/Library/Application Support/Aquarium/
#    - Clears the UserDefaults domain
#    - Does NOT touch Homebrew (ffmpeg/yt-dlp/aria2) since they're useful
#      elsewhere and you almost certainly want to keep them.
# ----------------------------------------------------------------------------

set -e
HERE="${0:A:h}"

echo "› removing symlinks"
rm -f /usr/local/bin/aquarium 2>/dev/null || true
rm -f "$HOME/.local/bin/aquarium" 2>/dev/null || true

echo "› stopping any running instance"
pkill -f aquarium-bin 2>/dev/null || true

echo "› removing compiled binary"
rm -f "$HERE/bin/aquarium-bin"

echo "› removing video + support files"
rm -rf "$HOME/Library/Application Support/Aquarium"

echo "› clearing UserDefaults"
defaults delete com.harwelik.aquarium 2>/dev/null || true

echo "✓ done.  Homebrew packages (ffmpeg/yt-dlp/aria2) left alone."
