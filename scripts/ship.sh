#!/usr/bin/env bash
# Build the tree as a static linux/amd64 binary, smoke it under Docker's amd64
# emulation, and upload it as a policy version. Prints the ref the server
# assigned (`<name>:vN`), which is what every request and submission refers to.
#
#   scripts/ship.sh <bot-dir> <policy-name> [--tag KEY=VALUE ...]
#
# Does NOT submit: `coworld submit <ref> -l <league> --auto-champion always`
# is the separate, deliberate step. The smoke test only proves the binary
# starts and asks for its websocket; whether it plays is the simulator's job.
set -euo pipefail

BOT_DIR="$(cd "$1" && pwd)"; shift
NAME="$1"; shift
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${SHIP_OUT:-/tmp/ship-$NAME-$$}"
mkdir -p "$OUT"

export CTF_BOT_DEPS="${CTF_BOT_DEPS:-$REPO/.bot-deps}"
export BUILD_AMD64_CACHE="${BUILD_AMD64_CACHE:-/tmp/bot-amd64-cache}"
"$REPO/scripts/build_amd64.sh" "$BOT_DIR" "$OUT/bot.bin" >&2

# Smoke: without the URL the binary must fail loudly asking for it; with a
# dead URL it must print its seat line and retry the connect. Both prove the
# static link and the amd64 image run at all.
smoke_noenv() {
  docker run --rm --platform linux/amd64 -v "$OUT/bot.bin:/opt/bot:ro" \
    debian:bookworm-slim sh -c '/opt/bot; true' 2>&1 | grep -q "COWORLD_PLAYER_WS_URL"
}
# Two tries: the first amd64 run after an image pull has flaked once.
if ! smoke_noenv && ! smoke_noenv; then
  echo "smoke failed: binary did not ask for COWORLD_PLAYER_WS_URL" >&2
  exit 1
fi
if ! docker run --rm --platform linux/amd64 \
     -e COWORLD_PLAYER_WS_URL='ws://127.0.0.1:1/player?slot=0&token=x' \
     -v "$OUT/bot.bin:/opt/bot:ro" debian:bookworm-slim \
     sh -c 'timeout 4 /opt/bot; true' 2>&1 | grep -q "connect retry"; then
  echo "smoke failed: binary did not reach the connect loop" >&2
  exit 1
fi
echo "smoke ok" >&2

uv run --no-project --with coworld==0.1.44 python \
  "$REPO/scripts/upload_amd64_policy.py" "$OUT/bot.bin" -n "$NAME" "$@"
