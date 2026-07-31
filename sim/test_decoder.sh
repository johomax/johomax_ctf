#!/usr/bin/env bash
# Compile and run the policy decoder's malformed-packet tests
# (sim/tests/decoder_test.nim) against one policy tree.
#
#   test_decoder.sh [tree] [workdir]
#
# Lays the tree out the way build.sh lays one out for host.nim — the test
# file copied INTO the tree so its `import protocols` binds there — and
# builds with checks and assertions on (a debug build on purpose: this is
# a correctness gate, not a benchmark). Run by `local_sim.py selfcheck`.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SIM_DIR/.." && pwd)"

TREE="$(cd "${1:-$REPO_DIR/bot/baseline}" && pwd)"
WORK="${2:-$REPO_DIR/.sim-build-decoder}"
ENGINE_DIR="${CTF_ENGINE_DIR:-$REPO_DIR/.engine}"

if [ ! -f "$ENGINE_DIR/nim.cfg" ]; then
  echo "no $ENGINE_DIR/nim.cfg -- run sim/bootstrap.sh first" >&2
  exit 1
fi
export PATH="${NIM_BIN_DIR:-$HOME/.nimby/nim/bin}:$PATH"
command -v nim >/dev/null || { echo "nim not on PATH -- run sim/bootstrap.sh" >&2; exit 1; }
if [ ! -f "$TREE/protocols.nim" ]; then
  echo "$TREE is not a policy tree (no protocols.nim)" >&2
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"
cp "$TREE"/*.nim "$WORK/"
cp "$SIM_DIR/tests/decoder_test.nim" "$WORK/"

# The engine's nimby-generated nim.cfg carries the dependency paths the
# policy needs (bitworld, supersnappy, whisky); the engine src itself is not
# imported by this test.
{
  cat "$ENGINE_DIR/nim.cfg"
  echo "--path:\"$ENGINE_DIR/src\""
} > "$WORK/nim.cfg"

cd "$WORK"
nim c -r \
  --hints:off \
  --warning:UnusedImport:off \
  --nimcache:"$WORK/nimcache" \
  --out:"$WORK/decoder_test" \
  decoder_test.nim
