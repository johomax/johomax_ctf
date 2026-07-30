#!/bin/bash
# Run the queued lever experiments strictly one at a time.
#
# Both directions of ONE experiment are created together and run concurrently
# -- that is the whole point, everything that drifts drifts for both and
# cancels. The next experiment is not created until the current pair has
# finished, so no two experiments ever share a slice of league time either.
#
# Resumable: an experiment whose name is already in results/summary.tsv is
# skipped, so a driver that dies partway can simply be restarted.
set -u
cd "$(dirname "$0")/.."
export COWORLD_BIN="${COWORLD_BIN:-/home/user/.cwvenv/bin/coworld}"
SUMMARY=results/summary.tsv

# name treatment control
QUEUE=(
  "arcraid    v30 v29"
  "aimband    v31 v29"
  "starebreak v32 v29"
  "nadeduck   v33 v29"
  "holdline   v34 v29"
  "hurtlook   v35 v29"
  "crossfire  v38 v34"
  "carriershy v36 v29"
  "odds       v37 v29"
  "holdeven   v39 v34"
  "shoutseen  v41 v40"
  "spawnintel v42 v41"
  "shoutintel v41 v29"
)

for entry in "${QUEUE[@]}"; do
  set -- $entry
  name="$1"; treat="jordan-ctf-candidate:$2"; ctrl="jordan-ctf-candidate:$3"

  if [ -f "$SUMMARY" ] && cut -f1 "$SUMMARY" | grep -qx "$name"; then
    echo "=== SKIP $name (already recorded)"
    continue
  fi

  echo "=== START $name  treatment=$treat control=$ctrl  $(date -u +%H:%M:%S)"
  out=$(python3 scripts/run_experiment.py "$name" "$treat" "$ctrl" 40 2>&1)
  echo "$out"
  xa=$(echo "$out" | sed -n 's/^XREQ_A=//p')
  xb=$(echo "$out" | sed -n 's/^XREQ_B=//p')
  if [ -z "$xa" ] || [ -z "$xb" ]; then
    echo "!!! $name produced no request ids; stopping"; exit 1
  fi

  echo "=== POOL $name $xa $xb"
  python3 scripts/pool_and_record.py "$name" "$treat" "$ctrl" "$xa" "$xb" \
    || echo "!!! pooling failed for $name (requests $xa $xb) -- continuing"
  echo "=== END $name $(date -u +%H:%M:%S)"
done

echo "=== ALL EXPERIMENTS DONE $(date -u +%H:%M:%S)"
