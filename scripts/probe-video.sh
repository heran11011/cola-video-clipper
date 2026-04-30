#!/bin/bash
# probe-video.sh — Quick probe of video metadata for the clip-maker workflow
# Usage: ./probe-video.sh <video_file>
#
# Outputs: duration, resolution, frame rate, codec, file size in human-readable format.
# Also prints a machine-readable JSON summary to stdout (last line).

set -euo pipefail

INPUT="$1"

if [ ! -f "$INPUT" ]; then
  echo "❌ File not found: $INPUT"
  exit 1
fi

if ! command -v ffprobe &>/dev/null; then
  echo "❌ ffprobe not found. Install ffmpeg: brew install ffmpeg"
  exit 1
fi

# Get file size
FILE_SIZE=$(du -h "$INPUT" | cut -f1)
FILE_SIZE_BYTES=$(stat -f%z "$INPUT" 2>/dev/null || stat --printf="%s" "$INPUT" 2>/dev/null || echo "0")

# Probe with ffprobe
PROBE_JSON=$(ffprobe -v quiet -print_format json -show_format -show_streams "$INPUT")

# Extract video stream info
DURATION=$(echo "$PROBE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
dur = float(data.get('format', {}).get('duration', 0))
h = int(dur // 3600)
m = int((dur % 3600) // 60)
s = dur % 60
print(f'{h:02d}:{m:02d}:{s:05.2f}')
" 2>/dev/null || echo "00:00:00")

DURATION_SEC=$(echo "$PROBE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('format', {}).get('duration', '0'))
" 2>/dev/null || echo "0")

VIDEO_INFO=$(echo "$PROBE_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for s in data.get('streams', []):
    if s.get('codec_type') == 'video':
        w = s.get('width', '?')
        h = s.get('height', '?')
        codec = s.get('codec_name', '?')
        # Frame rate
        r_frame = s.get('r_frame_rate', '0/1')
        parts = r_frame.split('/')
        if len(parts) == 2 and int(parts[1]) > 0:
            fps = round(int(parts[0]) / int(parts[1]), 2)
        else:
            fps = 0
        print(f'{w}x{h}|{codec}|{fps}')
        break
else:
    print('?x?|?|0')
" 2>/dev/null || echo "?x?|?|0")

RESOLUTION=$(echo "$VIDEO_INFO" | cut -d'|' -f1)
CODEC=$(echo "$VIDEO_INFO" | cut -d'|' -f2)
FPS=$(echo "$VIDEO_INFO" | cut -d'|' -f3)

# Human-readable output
echo "╔══════════════════════════════════════╗"
echo "║       📹 Video Probe Results        ║"
echo "╠══════════════════════════════════════╣"
echo "║  File:       $(basename "$INPUT")"
echo "║  Duration:   $DURATION ($DURATION_SEC s)"
echo "║  Resolution: $RESOLUTION"
echo "║  Frame Rate: ${FPS} fps"
echo "║  Codec:      $CODEC"
echo "║  File Size:  $FILE_SIZE"
echo "╚══════════════════════════════════════╝"

# Machine-readable JSON (last line, for scripting)
echo ""
echo "{\"file\":\"$INPUT\",\"duration_sec\":$DURATION_SEC,\"duration_fmt\":\"$DURATION\",\"resolution\":\"$RESOLUTION\",\"fps\":$FPS,\"codec\":\"$CODEC\",\"file_size\":\"$FILE_SIZE\",\"file_size_bytes\":$FILE_SIZE_BYTES}"
