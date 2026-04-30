#!/bin/bash
# cut-clips.sh — Batch cut clips from a source video using ffmpeg
# Usage: ./cut-clips.sh <input_video> <output_dir> <clips_csv>
#
# clips_csv format (one line per clip, no header):
#   start_time,end_time,output_filename
#   00:01:23,00:02:45,01-粉丝不到7000月入超薪资.mp4
#   00:05:10,00:05:41,02-一条视频爆了商单不断.mp4
#
# All times in HH:MM:SS or HH:MM:SS.mmm format.

set -euo pipefail

INPUT="$1"
OUTPUT_DIR="$2"
CLIPS_CSV="$3"

if [ ! -f "$INPUT" ]; then
  echo "❌ Input video not found: $INPUT"
  exit 1
fi

if [ ! -f "$CLIPS_CSV" ]; then
  echo "❌ Clips CSV not found: $CLIPS_CSV"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "🎬 Source: $INPUT"
echo "📁 Output: $OUTPUT_DIR"
echo ""

# Probe source video
echo "🔍 Probing source video..."
ffprobe -v quiet -print_format json -show_format -show_streams "$INPUT" > "$OUTPUT_DIR/source-info.json"
echo "✅ Source info saved to $OUTPUT_DIR/source-info.json"
echo ""

# Count total clips for progress display
TOTAL_CLIPS=$(grep -c . "$CLIPS_CSV" || echo 0)
echo "📋 Total clips to cut: $TOTAL_CLIPS"
echo ""

# Track overall timing
OVERALL_START=$(date +%s)

# Cut each clip
CLIP_NUM=0
SUCCESS_COUNT=0
FAIL_COUNT=0

while IFS=',' read -r START END FILENAME; do
  CLIP_NUM=$((CLIP_NUM + 1))

  # Trim whitespace
  START=$(echo "$START" | xargs)
  END=$(echo "$END" | xargs)
  FILENAME=$(echo "$FILENAME" | xargs)

  # Skip empty lines
  [ -z "$START" ] && continue

  OUTPUT_PATH="$OUTPUT_DIR/$FILENAME"

  # Progress percentage
  PERCENT=$(( CLIP_NUM * 100 / TOTAL_CLIPS ))
  echo "✂️  [$CLIP_NUM/$TOTAL_CLIPS] (${PERCENT}%) $START → $END → $FILENAME"

  CLIP_START=$(date +%s)

  # Use re-encode for precise cuts
  if ffmpeg -i "$INPUT" \
    -ss "$START" -to "$END" \
    -c:v libx264 -preset fast -crf 18 \
    -c:a aac -b:a 192k \
    -vsync cfr \
    -y "$OUTPUT_PATH" 2>/dev/null; then

    CLIP_END=$(date +%s)
    CLIP_TIME=$((CLIP_END - CLIP_START))

    # Get file size
    SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
    # Get duration
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$OUTPUT_PATH" | xargs printf "%.1f")

    echo "   ✅ Done — ${DURATION}s, ${SIZE}, took ${CLIP_TIME}s"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "   ⚠️  Failed with original filename — trying numbered fallback..."
    FALLBACK="$OUTPUT_DIR/clip-$(printf '%02d' $CLIP_NUM).mp4"
    if ffmpeg -i "$INPUT" \
      -ss "$START" -to "$END" \
      -c:v libx264 -preset fast -crf 18 \
      -c:a aac -b:a 192k \
      -vsync cfr \
      -y "$FALLBACK" 2>/dev/null; then

      CLIP_END=$(date +%s)
      CLIP_TIME=$((CLIP_END - CLIP_START))

      SIZE=$(du -h "$FALLBACK" | cut -f1)
      DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$FALLBACK" | xargs printf "%.1f")
      echo "   ✅ Fallback done — ${DURATION}s, ${SIZE}, took ${CLIP_TIME}s (saved as $(basename "$FALLBACK"))"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      echo "   ❌ Clip $CLIP_NUM failed completely — skipping"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi

  echo ""
done < "$CLIPS_CSV"

# Summary
OVERALL_END=$(date +%s)
OVERALL_TIME=$((OVERALL_END - OVERALL_START))
MINUTES=$((OVERALL_TIME / 60))
SECONDS=$((OVERALL_TIME % 60))

echo "════════════════════════════════════════"
echo "🎉 Batch cut complete!"
echo "   ✅ Success: $SUCCESS_COUNT / $TOTAL_CLIPS"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "   ❌ Failed:  $FAIL_COUNT / $TOTAL_CLIPS"
fi
echo "   ⏱️  Total time: ${MINUTES}m ${SECONDS}s"
echo "   📁 Output: $OUTPUT_DIR/"
echo "════════════════════════════════════════"
