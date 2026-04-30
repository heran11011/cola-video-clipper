#!/bin/bash
# extract-frames.sh — Extract a representative frame from each clip for cover art
# Usage: ./extract-frames.sh <clips_dir>
#
# Smart frame selection: picks a frame at 1/3 of clip duration
# (avoids black intro frames at the start and fade-out at the end).

set -euo pipefail

CLIPS_DIR="$1"

if [ ! -d "$CLIPS_DIR" ]; then
  echo "❌ Directory not found: $CLIPS_DIR"
  exit 1
fi

COVERS_DIR="$CLIPS_DIR/covers"
mkdir -p "$COVERS_DIR"

echo "🖼️  Extracting cover frames from clips in $CLIPS_DIR"
echo "   Strategy: smart selection at 1/3 duration (avoid black/fade)"
echo ""

COUNT=0
SUCCESS=0

for VIDEO in "$CLIPS_DIR"/*.mp4; do
  [ -f "$VIDEO" ] || continue

  COUNT=$((COUNT + 1))
  BASENAME=$(basename "$VIDEO" .mp4)
  OUTPUT="$COVERS_DIR/${BASENAME}-frame.jpg"

  # Get clip duration in seconds
  DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null || echo "0")

  if [ -z "$DURATION" ] || [ "$DURATION" = "0" ]; then
    echo "   ⚠️  $BASENAME — cannot read duration, using 2s fallback"
    TIMESTAMP="00:00:02"
  else
    # Calculate 1/3 position (biased toward front but past any intro)
    # Using awk for floating point math
    TIMESTAMP=$(echo "$DURATION" | awk '{
      pos = $1 / 3;
      if (pos < 1) pos = 1;
      h = int(pos / 3600);
      m = int((pos - h*3600) / 60);
      s = pos - h*3600 - m*60;
      printf "%02d:%02d:%05.2f", h, m, s
    }')
  fi

  if ffmpeg -i "$VIDEO" -ss "$TIMESTAMP" -frames:v 1 -q:v 2 -y "$OUTPUT" 2>/dev/null; then
    echo "   ✅ $BASENAME → $(basename "$OUTPUT") (at $TIMESTAMP)"
    SUCCESS=$((SUCCESS + 1))
  else
    # Fallback: try at 1 second
    if ffmpeg -i "$VIDEO" -ss 00:00:01 -frames:v 1 -q:v 2 -y "$OUTPUT" 2>/dev/null; then
      echo "   ✅ $BASENAME → $(basename "$OUTPUT") (1s fallback)"
      SUCCESS=$((SUCCESS + 1))
    else
      # Last resort: first frame
      if ffmpeg -i "$VIDEO" -frames:v 1 -q:v 2 -y "$OUTPUT" 2>/dev/null; then
        echo "   ✅ $BASENAME → $(basename "$OUTPUT") (first frame fallback)"
        SUCCESS=$((SUCCESS + 1))
      else
        echo "   ❌ $BASENAME — frame extraction failed"
      fi
    fi
  fi
done

echo ""
echo "🎉 Done — $SUCCESS/$COUNT frames extracted to $COVERS_DIR/"
