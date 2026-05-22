#!/usr/bin/env zsh
# ----------------------------------------------------------------------------
#  fetch-video.sh — pull a real 4K HDR coral-reef clip + blur its watermark.
#  Author: Anthony Harwelik <aharwelik@gmail.com>
#
#  What it does, in order:
#    1.  Downloads the first ~16 minutes of a 4K60 HDR (vp9.2) coral-reef clip
#        from YouTube using yt-dlp + aria2c with 16 parallel connections.
#    2.  Re-encodes to HEVC main10 with M1's VideoToolbox hardware encoder,
#        applying a localized Gaussian blur to the "Aura Video Art" watermark
#        in the bottom-left corner. The blur covers a 580x130 px rectangle —
#        the rest of the 3840x2160 frame is untouched.
#    3.  Installs the result to ~/Library/Application Support/Aquarium/.
#
#  Why these choices:
#    - YouTube no longer serves HEVC for community uploads, so we have to
#      transcode anyway.  Might as well do the watermark fix in the same pass.
#    - 16-min slice is plenty: the Swift player stops at 15 min by default.
#    - HEVC main10 + p010le keeps the original HDR10 colour space intact, so
#      Anthony's MacBook XDR display gets real HDR (not tone-mapped).
#
#  Requirements (all installed by ../install.sh if missing):
#    yt-dlp, aria2c, ffmpeg, Apple Silicon Mac running macOS 13+.
# ----------------------------------------------------------------------------

set -e

YOUTUBE_ID="${AQUARIUM_VIDEO_ID:-eHxbMa2RVTQ}"   # override via env if needed
SLICE_SECONDS=960                                 # 16 minutes
WATERMARK_CROP="580:130:0:2040"                  # WxH:X:Y in 4K coords
BLUR_SIGMA=40

DEST_DIR="$HOME/Library/Application Support/Aquarium"
WORK_DIR="${TMPDIR:-/tmp}/aquarium-fetch.$$"
mkdir -p "$DEST_DIR" "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "› downloading source (4K60 HDR vp9.2)…"
cd "$WORK_DIR"
yt-dlp --no-playlist --no-progress \
       --external-downloader aria2c \
       --external-downloader-args "aria2c:-x16 -s16 -k 1M --console-log-level=warn" \
       -f "337+251/337+140/315+251/315+140/336+251/336+140" \
       --merge-output-format mkv \
       -o "source.%(ext)s" \
       "https://www.youtube.com/watch?v=$YOUTUBE_ID"

echo "› transcoding to HEVC with watermark blur (~7-10 min on M1 Max)…"
ffmpeg -y -hide_banner -loglevel warning \
       -t "$SLICE_SECONDS" -i source.mkv \
       -filter_complex "[0:v]split[base][in];[in]crop=${WATERMARK_CROP},gblur=sigma=${BLUR_SIGMA}[blur];[base][blur]overlay=0:2040:format=auto[v]" \
       -map "[v]" -map 0:a:0 \
       -c:v hevc_videotoolbox -b:v 30M -tag:v hvc1 \
       -profile:v main10 -pix_fmt p010le \
       -colorspace bt2020nc -color_primaries bt2020 -color_trc smpte2084 \
       -c:a aac -b:a 192k \
       -movflags +faststart \
       "$DEST_DIR/aquarium.mp4"

echo "› installed to: $DEST_DIR/aquarium.mp4"
echo "› size: $(ls -lh "$DEST_DIR/aquarium.mp4" | awk '{print $5}')"
