#!/bin/bash
# Format all Swift files in the Luce app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if swift-format is installed
if ! command -v swift-format &> /dev/null; then
  echo "swift-format not found. Install with: brew install swift-format"
  exit 1
fi

# Find and list all Swift files
files=$(find "$SCRIPT_DIR" -name "*.swift" -not -path "*/.*")
count=$(echo "$files" | wc -l | tr -d ' ')

echo "Formatting $count Swift files:"
echo ""
echo "$files"
echo ""

# Format all files in parallel
swift-format format \
  --in-place \
  --recursive \
  --parallel \
  --configuration "$SCRIPT_DIR/.swift-format" \
  "$SCRIPT_DIR"

echo "Done."
