#!/bin/bash
# Local head-to-head: image A on the 8 even (red) slots, image B on the 8 odd
# (blue) slots, then swapped. Same both-directions discipline as the hosted
# runs -- a single direction cannot separate "better build" from "better side".
# Expects `coworld` on PATH and a downloaded coworld manifest under cwpkg/.
cd "$(dirname "$0")/.."
MAN=$(ls cwpkg/*/coworld_manifest.json)
A="$1"; B="$2"; N="${3:-8}"; OUT="$4"

slots() {  # $1 = image on even slots, $2 = image on odd slots
  local r=""
  for i in $(seq 0 15); do
    if [ $((i % 2)) -eq 0 ]; then r="$r $1"; else r="$r $2"; fi
  done
  echo "$r"
}

rm -rf "$OUT"
echo "direction 1: $A on red, $B on blue"
timeout 3000 coworld run-episode "$MAN" $(slots "$A" "$B") \
  -o "$OUT/dir1" -n "$N" --timeout-seconds 400 >/dev/null 2>&1
echo "direction 2: $B on red, $A on blue"
timeout 3000 coworld run-episode "$MAN" $(slots "$B" "$A") \
  -o "$OUT/dir2" -n "$N" --timeout-seconds 400 >/dev/null 2>&1
echo "done"
