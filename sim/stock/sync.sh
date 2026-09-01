#!/usr/bin/env bash
set -euo pipefail

STOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$STOCK_DIR/../.." && pwd)"
ENGINE_DIR="${CTF_ENGINE_DIR:-$REPO_DIR/.engine}"
UPSTREAM="$ENGINE_DIR/players/baseline"

for source in baseline.nim baseline/protocols.nim baseline/taunts.nim; do
  if [ ! -f "$UPSTREAM/$source" ]; then
    echo "missing stock source: $UPSTREAM/$source" >&2
    exit 1
  fi
done

cp "$UPSTREAM/baseline.nim" "$STOCK_DIR/stockbot.nim"
cp "$UPSTREAM/baseline/protocols.nim" "$STOCK_DIR/stockprotocols.nim"
cp "$UPSTREAM/baseline/taunts.nim" "$STOCK_DIR/stocktaunts.nim"

(
  cd "$STOCK_DIR"
  patch --batch --fuzz=0 -V none -p0 < adapter.patch
)

echo "synced stock bot from $(git -C "$ENGINE_DIR" rev-parse --short=8 HEAD)"
