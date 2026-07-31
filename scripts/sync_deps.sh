#!/usr/bin/env bash
# Clone a nimby.lock's dependency set at its pinned SHAs, without nimby.
#
#   sync_deps.sh <nimby.lock> <dest-dir>
#
# nimby's release binary is a glibc build and will not run on a musl box, so
# this does the only two things the build needs from it: every repo in the lock
# checked out at its pinned commit, and a `--path` line per dependency. The
# output is written twice under <dest-dir>, as `nim.cfg` (what sim/build.sh
# concatenates) and `paths.cfg` (what scripts/build_amd64.sh reads a line at a
# time) -- same bytes, two consumers.
#
# Idempotent and safe to re-run: a repo already at its pin is left alone.
set -euo pipefail

LOCK="$1"
DEST="$2"
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

while read -r name _version url sha; do
  [ -n "${name:-}" ] || continue
  case "$name" in \#*) continue ;; esac
  dir="$DEST/$name"
  if [ ! -d "$dir/.git" ]; then
    rm -rf "$dir"
    git clone -q --filter=blob:none "$url" "$dir"
  fi
  if [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" != "$sha" ]; then
    git -C "$dir" fetch -q --filter=blob:none origin "$sha" 2>/dev/null \
      || git -C "$dir" fetch -q origin
    git -C "$dir" checkout -q --detach "$sha"
  fi
done < "$LOCK"

# `src/` when the package has one, the repo root otherwise (libcurl).
: > "$DEST/nim.cfg"
for dir in "$DEST"/*/; do
  dir="${dir%/}"
  [ -d "$dir/.git" ] || continue
  if [ -d "$dir/src" ]; then echo "--path:\"$dir/src\""; else echo "--path:\"$dir\""; fi
done | sort > "$DEST/nim.cfg"
cp "$DEST/nim.cfg" "$DEST/paths.cfg"
echo "synced $(grep -c . "$DEST/nim.cfg") dependencies into $DEST"
