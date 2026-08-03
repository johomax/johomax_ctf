#!/usr/bin/env bash
# Build one simulator binary holding TWO policy trees -- or up to FOUR.
#
# A variant is a source change built as its own image (README.md), which leaves
# a head-to-head needing two policies alive at once. Nim gives that for free:
# modules are resolved relative to the importing file, so two copies of the
# policy tree in two directories are two distinct module sets with their own
# module-level state -- including `tuning.nim`'s adopted map dimensions and the
# nine globals derived from them. This script lays those copies out, drops a
# copy of sim/host.nim into each so its `import decide, ...` binds to the tree
# it sits in, and compiles them together.
#
#   build.sh [--tree-c DIR] [--tree-d DIR] <treeA> <treeB> <out-binary> [workdir]
#
# treeA / treeB are policy directories -- a `bot/baseline` from any checkout,
# worktree or `git archive` extraction. Pass the same path twice for an A/A
# null run.
#
# --tree-c / --tree-d exist for Paintbot, where an episode seats FOUR entrant
# policies (analysis/paintbot.md) and the faithful shape is four distinct ones.
# They are OPTIONAL and off by default because a tree is not free: each extra
# copy is a whole extra module set to compile, and the CTF head-to-head that
# runs a hundred times a day needs exactly two. It is cheaper than it sounds --
# the engine is the bulk of the build and is shared -- but it is not nothing:
# on this box, cold 16.9 s -> 19.8 s, warm (one policy file edited) 2.7 s ->
# 3.0 s. `simulate.nim` guards the extra imports behind -d:simBuilds, so a
# two-tree build compiles exactly what it always did.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SIM_DIR/.." && pwd)"

usage() {
  echo "usage: build.sh [--tree-c DIR] [--tree-d DIR] <treeA> <treeB> <out-binary> [workdir]" >&2
}

TREE_C=""
TREE_D=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tree-c) TREE_C="$(cd "$2" && pwd)"; shift 2 ;;
    --tree-d) TREE_D="$(cd "$2" && pwd)"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    --*) usage; exit 2 ;;
    *) break ;;
  esac
done

if [ $# -lt 3 ]; then
  usage
  exit 2
fi
# A gap in the lineup would put tree d behind the character 'c', so --assign
# would seat a build the caller never named. Refuse instead.
if [ -n "$TREE_D" ] && [ -z "$TREE_C" ]; then
  echo "--tree-d without --tree-c: the build characters must be contiguous" >&2
  exit 2
fi

TREE_A="$(cd "$1" && pwd)"
TREE_B="$(cd "$2" && pwd)"
# Resolve the output before anything cds: the compile runs from the work dir,
# where a relative path would land somewhere else entirely.
mkdir -p "$(dirname "$3")"
OUT="$(cd "$(dirname "$3")" && pwd)/$(basename "$3")"
WORK="${4:-$REPO_DIR/.sim-build}"
ENGINE_DIR="${CTF_ENGINE_DIR:-$REPO_DIR/.engine}"

SIDES=(a b)
TREES=("$TREE_A" "$TREE_B")
if [ -n "$TREE_C" ]; then SIDES+=(c); TREES+=("$TREE_C"); fi
if [ -n "$TREE_D" ]; then SIDES+=(d); TREES+=("$TREE_D"); fi

if [ ! -d "$ENGINE_DIR/src/ctf" ]; then
  echo "no engine at $ENGINE_DIR -- run sim/bootstrap.sh first" >&2
  exit 1
fi
if [ ! -f "$ENGINE_DIR/nim.cfg" ]; then
  echo "no $ENGINE_DIR/nim.cfg -- run sim/bootstrap.sh first" >&2
  exit 1
fi

export PATH="${NIM_BIN_DIR:-$HOME/.nimby/nim/bin}:$PATH"
command -v nim >/dev/null || { echo "nim not on PATH -- run sim/bootstrap.sh" >&2; exit 1; }

# Refuse to rebuild on top of a running experiment. The build replaces the
# policy trees and rewrites the output binary, which on Linux unlinks a
# binary that episodes in flight are still executing: the running ones
# survive on their open inode and finish normally, but the next episode the
# driver spawns gets ENOENT and takes the whole run down with it. Worse, a
# rebuild that DOES succeed mid-run leaves half a measurement produced by one
# binary and half by another.
if pgrep -f "^$WORK/simulate " >/dev/null 2>&1 || \
   pgrep -f "^$OUT " >/dev/null 2>&1; then
  echo "refusing to rebuild: episodes are still running from this build." >&2
  echo "wait for them, or build somewhere else:" >&2
  echo "  sim/build.sh <treeA> <treeB> /tmp/other-simulate /tmp/other-work" >&2
  exit 1
fi

# The bot's own Dockerfile adds --stackTrace:on, which costs about 30% of
# wall clock here and buys nothing a simulator run normally needs. Put it back
# through SIM_NIM_FLAGS when you are chasing a crash inside the policy:
#   SIM_NIM_FLAGS="-d:release --opt:speed --stackTrace:on" sim/build.sh ...
# Bounds checks stay on deliberately: -d:danger buys another ~18% and turns an
# out-of-range index in the policy from a crash into silence, which is the
# opposite of what a tool for finding behaviour bugs should do.
NIM_FLAGS="${SIM_NIM_FLAGS:--d:release -d:useMalloc --opt:speed}"
BUILD_COUNT_FLAG="-d:simBuilds=${#SIDES[@]}"

# The nimcache SURVIVES a rebuild, because a research loop builds far more
# often than it changes the engine. A build is two policy trees against a
# fixed engine, and the engine is most of the code: recompiling it for a
# one-file policy edit was ~26 s of every head-to-head.
#
# What makes that safe is Nim's own content hashing: a module whose text
# changed regenerates its C and recompiles, and the trees are copied in fresh
# every build, so which policy sits in a/ is covered. What Nim does NOT see is
# everything that is not a source file -- the flags, the compiler, the engine
# the generated nim.cfg points at. Those go in a STAMP, and a stamp that does
# not match the one beside the cache throws the cache away. One gate over all
# of them beats one name-field per remembered input: when a new input turns
# up, it goes in the stamp and every stale cache is discarded by the check
# that is already here. Both compilers are in it: nim regenerates C, and the
# C compiler turns that C into the objects the cache actually holds, so a
# toolchain upgrade under unchanged .c files would otherwise relink stale
# ones.
#
# SIM_CLEAN=1 forces a cold build. Nothing here needs it -- it is for the
# moment you stop believing the cache, which is a moment worth having an
# answer for.
NIMCACHE="$WORK/nimcache"
STAMP="$WORK/build-inputs"
STAMP_NOW="$NIM_FLAGS $BUILD_COUNT_FLAG
$(nim --version | head -1)
$( { ${CC:-gcc} --version 2>/dev/null || echo 'no c compiler on PATH'; } | head -1)
$ENGINE_DIR"
if [ -n "${SIM_CLEAN:-}" ] || [ "$(cat "$STAMP" 2>/dev/null)" != "$STAMP_NOW" ]; then
  rm -rf "$NIMCACHE"
fi
# All four, always: a c/ left behind by an earlier four-tree build in this work
# dir is a policy tree nothing in this one refreshed, and Nim would happily
# compile it if a later build turned -d:simBuilds back up.
rm -rf "$WORK/a" "$WORK/b" "$WORK/c" "$WORK/d"

for i in "${!SIDES[@]}"; do
  side="${SIDES[$i]}"
  src="${TREES[$i]}"
  if [ ! -f "$src/decide.nim" ]; then
    echo "$src is not a policy tree (no decide.nim)" >&2
    exit 1
  fi
  mkdir -p "$WORK/$side"
  cp "$src"/*.nim "$WORK/$side/"
  cp "$SIM_DIR/host.nim" "$WORK/$side/host.nim"
done

cp "$SIM_DIR/simulate.nim" "$WORK/simulate.nim"

# The engine's nimby-generated nim.cfg already carries every dependency path
# (including the bitworld the ENGINE is pinned to -- the policy's compile-time
# ButtonC tripwire in protocols.nim checks that this one passes bit 128, and
# fails the build here if it does not). Add the engine's own src/ for `ctf/*`.
{
  cat "$ENGINE_DIR/nim.cfg"
  echo "--path:\"$ENGINE_DIR/src\""
} > "$WORK/nim.cfg"

cd "$WORK"
# shellcheck disable=SC2086
nim c \
  $NIM_FLAGS \
  "$BUILD_COUNT_FLAG" \
  --hints:off \
  --warning:UnusedImport:off \
  --nimcache:"$NIMCACHE" \
  --out:"$OUT" \
  simulate.nim

# Only now: a stamp written before the compile would outlive a build that
# failed halfway and vouch for a cache nothing finished filling. `set -e`
# means a failed compile never reaches this line, so the next build finds no
# stamp and starts cold.
printf '%s' "$STAMP_NOW" > "$STAMP"

echo "built $OUT"
for i in "${!SIDES[@]}"; do
  echo "  ${SIDES[$i]} = ${TREES[$i]}"
done
echo "  engine = $ENGINE_DIR"
