#!/bin/bash
set -e

echo "=== English-Only ConceptNet Export ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT="$SCRIPT_DIR/data/conceptnet-assertions-5.7.0.csv"
TEMP="$SCRIPT_DIR/data/temp_en_start.csv"
OUTPUT="$SCRIPT_DIR/data/en-conceptnet-assertions-5.7.0.csv"

# Verify input exists
if [ ! -f "$INPUT" ]; then
    echo "ERROR: $INPUT not found."
    echo "Download and decompress the full ConceptNet dump into data/."
    exit 1
fi

echo "Input row count:"
wc -l "$INPUT"
echo ""

# Pass 1: Keep rows where start node (col 3) begins with /c/en/
echo "Pass 1: Filtering rows with English start node..."
awk -F'\t' '$3 ~ /^\/c\/en\//' "$INPUT" > "$TEMP"
echo "Pass 1 complete. Intermediary row count:"
wc -l "$TEMP"
echo ""

# Pass 2: From intermediary, keep rows where end node (col 4) also begins with /c/en/
echo "Pass 2: Filtering rows with English end node..."
awk -F'\t' '$4 ~ /^\/c\/en\//' "$TEMP" > "$OUTPUT"
echo "Pass 2 complete. Output row count:"
wc -l "$OUTPUT"
echo ""

# Cleanup
rm "$TEMP"
echo "Removed intermediary file ($TEMP)."
echo ""
echo "=== Done. Output: $OUTPUT ==="
