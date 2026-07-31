#!/usr/bin/env bash
# Mirror a build of ours against coworld-ctf's default player, locally.
#
#   sim/opponents/h2h.sh [seeds] [our-side] [first-seed]
#
# seeds defaults to 40 (80 episodes, both directions -- README.md rule 5's
# floor); our-side defaults to bot/baseline and takes anything local_sim.py
# takes, so `sim/opponents/h2h.sh 40 HEAD~3` works.
#
# first-seed moves the seed block, which is what a confirmation run needs:
# rule 5 wants the marginal call re-mirrored and decided on the pooled total,
# and `pool` keys its pairs by seed, so a second run on the same block would
# pool as forty pairs of four rather than eighty pairs of two.
#
#   sim/opponents/h2h.sh 40                        # seeds 1000-1039
#   sim/opponents/h2h.sh 40 bot/baseline 2000      # seeds 2000-2039
#   cat episodes/vs-default-*.jsonl > /tmp/both.jsonl
#   scripts/local_sim.py pool /tmp/both.jsonl --name-a ours --name-b default
#
# Two things this wraps, both of which are wrong by default:
#
#   * the opponent tree has to be regenerated, because it is a rewrite of a
#     file in the engine checkout and nothing else notices when that moves;
#   * `-d:artlogNoCurl` has to be on. Upstream's telemetry module links
#     libcurl otherwise, this box has only libcurl-gnutls, and the failure is
#     a dynlib error at the first episode rather than at the build. The flag
#     is upstream's own (players/baseline/README.md): it drops the HTTP
#     delivery path and keeps the rest of the module compiled in, and no
#     artifact is uploaded from a simulator run either way.
#
# SIM_NIM_FLAGS is composed rather than replaced, so overriding it from the
# environment still gets the curl flag.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$SIM_DIR/.." && pwd)"

SEEDS="${1:-40}"
OURS="${2:-bot/baseline}"
FIRST_SEED="${3:-1000}"
TREE=".opponents/coworld-baseline"

# From the repo root, so both sides are named by a short relative path -- those
# names are what the report and the `pool` command line carry.
cd "$REPO_DIR"

python3 "$SIM_DIR/opponents/make_tree.py" --out "$TREE"
echo

export SIM_NIM_FLAGS="${SIM_NIM_FLAGS:--d:release -d:useMalloc --opt:speed} -d:artlogNoCurl"
exec python3 scripts/local_sim.py h2h "$OURS" "$TREE" -n "$SEEDS" \
  --first-seed "$FIRST_SEED" \
  --out "episodes/vs-default-$(date +%Y%m%d-%H%M%S).jsonl"
