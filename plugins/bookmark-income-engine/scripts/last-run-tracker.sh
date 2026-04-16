#!/bin/bash
# Bookmark Income Engine — Last Run Tracker
# Appends a timestamp to the dedup file so future runs skip already-processed bookmarks
#
# Usage: ./last-run-tracker.sh [output_dir]
# Default output_dir is ./output relative to the plugin root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${1:-$PLUGIN_DIR/output}"
LAST_RUN_FILE="$OUTPUT_DIR/.last-run"

mkdir -p "$OUTPUT_DIR"

if [ ! -f "$LAST_RUN_FILE" ]; then
  echo "# Bookmark Income Engine — Processed Bookmarks Tracker" > "$LAST_RUN_FILE"
  echo "# Each run appends a timestamp and list of processed bookmark URLs" >> "$LAST_RUN_FILE"
  echo "" >> "$LAST_RUN_FILE"
fi

echo "---" >> "$LAST_RUN_FILE"
echo "run_date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LAST_RUN_FILE"
echo "urls:" >> "$LAST_RUN_FILE"
# URLs are appended by the orchestrator agent during processing
