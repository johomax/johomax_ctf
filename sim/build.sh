#!/usr/bin/env bash
# Build one simulator binary holding TWO policy trees.
#
# A variant is a source change built as its own image (README.md), which leaves
# a head-to-head needing two policies alive at once. Nim gives that for free:
# modules are resolved relative to the importing file, so two copies of the
# policy tree in two directories are two distinct module sets with their own
# module-level state -- including `tuning.nim`'s adopted map dimensions and the
# nine globals derived from them. This script lays those copies out, drops a
# copy of sim/host.nim into each so its `import decide, ...` binds to the tree
# it sits in, and compiles the three together.
#
#   build.sh <treeA> <treeB> <out-binary> [workdir]
#
# treeA / treeB are policy directories -- a `bot/baseline` from any checkout,
# worktree or `git archive` extraction. Pass the same path twice for an A/A
# null run.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SIM_DIR/.." && pwd)"

if [ $# -lt 3 ]; then
  echo "usage: build.sh <treeA> <treeB> <out-binary> [workdir]" >&2
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

# Refuse to rebuild on top of a running experiment. The work dir is wiped
# below, which on Linux unlinks a binary that episodes in flight are still
# executing: the running ones survive on their open inode and finish normally,
# but the next episode the driver spawns gets ENOENT and takes the whole run
# down with it. Worse, a rebuild that DOES succeed mid-run leaves half a
# measurement produced by one binary and half by another.
if pgrep -f "^$WORK/simulate " >/dev/null 2>&1 || \
   pgrep -f "^$OUT " >/dev/null 2>&1; then
  echo "refusing to rebuild: episodes are still running from this build." >&2
  echo "wait for them, or build somewhere else:" >&2
  echo "  sim/build.sh <treeA> <treeB> /tmp/other-simulate /tmp/other-work" >&2
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK/a" "$WORK/b"

for side in a b; do
  case "$side" in
    a) src="$TREE_A" ;;
    b) src="$TREE_B" ;;
  esac
  if [ ! -f "$src/decide.nim" ]; then
    echo "$src is not a policy tree (no decide.nim)" >&2
    exit 1
  fi
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

# The bot's own Dockerfile adds --stackTrace:on, which costs about 30% of
# wall clock here and buys nothing a simulator run normally needs. Put it back
# through SIM_NIM_FLAGS when you are chasing a crash inside the policy:
#   SIM_NIM_FLAGS="-d:release --opt:speed --stackTrace:on" sim/build.sh ...
# Bounds checks stay on deliberately: -d:danger buys another ~18% and turns an
# out-of-range index in the policy from a crash into silence, which is the
# opposite of what a tool for finding behaviour bugs should do.
NIM_FLAGS="${SIM_NIM_FLAGS:--d:release -d:useMalloc --opt:speed}"

cd "$WORK"
# shellcheck disable=SC2086
nim c \
  $NIM_FLAGS \
  --hints:off \
  --warning:UnusedImport:off \
  --nimcache:"$WORK/nimcache" \
  --out:"$OUT" \
  simulate.nim

echo "built $OUT"
echo "  a = $TREE_A"
echo "  b = $TREE_B"
echo "  engine = $ENGINE_DIR"
