#!/usr/bin/env bash
# Prove the patched engine reproduces the UNPATCHED one, episode for episode.
#
# This is the check the whole of engine-patches/perf.patch rests on: every
# hunk in it is allowed to be fast only because the game it produces is the
# game upstream's own code produces. It was a manual ritual -- clone .engine
# somewhere, revert it, build a second binary, run both, eyeball the hashes --
# which meant the claim in the patch header aged without anything able to
# re-check it. This is that ritual, once, so a moved pin or a new hunk can be
# answered with a command instead of a memory.
#
#   sim/stock_compare.sh                 # every config, a few seeds each
#   sim/stock_compare.sh 4               # 4 seeds per config instead of 3
#
# It builds TWO simulators from the same policy tree: one against the managed
# (patched) .engine, one against a pristine copy of the same commit with the
# patch reverted. Same tree, same seeds, same assigns -- the engine is the
# only variable, which is what makes an identical gameHash mean what it says.
#
# Costs what the stock engine costs, which is the point of the patch: expect
# roughly ten minutes, most of it the unpatched side.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SIM_DIR/.." && pwd)"
SEEDS_PER_CONFIG="${1:-3}"
ENGINE_DIR="${CTF_ENGINE_DIR:-$REPO_DIR/.engine}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ctf-stock-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [ ! -d "$ENGINE_DIR/src/ctf" ]; then
  echo "no engine at $ENGINE_DIR -- run sim/bootstrap.sh first" >&2
  exit 1
fi

echo "== patched engine   : $ENGINE_DIR ($(git -C "$ENGINE_DIR" rev-parse --short HEAD))"
# A pristine copy of the SAME commit. `checkout -- .` drops the applied
# patches and nothing else, so the two sides differ by exactly perf.patch.
cp -a "$ENGINE_DIR" "$WORK/stock"
git -C "$WORK/stock" checkout -- .
if ! git -C "$WORK/stock" diff --quiet; then
  echo "the stock copy is not clean after checkout -- refusing to compare" >&2
  exit 1
fi
echo "== stock engine     : the same commit with perf.patch reverted"

echo "== building both (the stock side has no patch, so it compiles cold)"
"$SIM_DIR/build.sh" "$REPO_DIR/bot/baseline" "$REPO_DIR/bot/baseline" \
  "$WORK/simulate-patched" "$WORK/build-patched" >/dev/null
CTF_ENGINE_DIR="$WORK/stock" "$SIM_DIR/build.sh" \
  "$REPO_DIR/bot/baseline" "$REPO_DIR/bot/baseline" \
  "$WORK/simulate-stock" "$WORK/build-stock" >/dev/null

# One line per episode: config, seed, ticks, ending, hash. Every config the
# repo carries, so a hunk that only bites on one board cannot hide.
hashes() { # <binary> <engine>
  for config in "$SIM_DIR"/league_config.json "$SIM_DIR"/paintbot_*.json; do
    slots="$(python3 -c "
import json,sys
print(len(json.load(open(sys.argv[1])).get('slots') or []) or 16)" "$config")"
    seeds="$(python3 -c "
print(','.join(str(900001 + i) for i in range($SEEDS_PER_CONFIG)))")"
    "$1" --engine "$2" --config "$config" --seeds "$seeds" \
      --assign "$(printf 'a%.0s' $(seq "$slots"))" --quiet 2>/dev/null \
    | python3 -c "
import sys, json, os
name = os.path.basename('$config')
for line in sys.stdin:
    r = json.loads(line)
    print(f\"{name:24} seed {r['seed']:7} ticks {r['ticks']:5} \"
          f\"{r['ending']:9} {r['gameHash']}\")
"
  done
}

echo "== running the patched engine"
hashes "$WORK/simulate-patched" "$ENGINE_DIR" > "$WORK/patched.txt"
echo "== running the stock engine (slower, by the whole point of the patch)"
hashes "$WORK/simulate-stock" "$WORK/stock" > "$WORK/stock.txt"

echo
if diff -u "$WORK/stock.txt" "$WORK/patched.txt"; then
  echo "$(wc -l < "$WORK/patched.txt") episodes, every gameHash identical."
  echo "perf.patch reproduces the unmodified upstream engine."
else
  echo
  echo "DIVERGED. A hunk in engine-patches/perf.patch changes the game." >&2
  echo "Do not trust any measurement taken since it landed." >&2
  exit 1
fi
