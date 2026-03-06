#!/usr/bin/env bash
# Pin current Guix channel commits into channels.scm.
# Run this whenever you want to update the reproducible baseline.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/channels.scm"

echo "Querying current Guix channel commits..."
guix describe -f channels > "$OUT"
echo "Pinned channels written to $OUT"
echo "Verify with: cat $OUT"
