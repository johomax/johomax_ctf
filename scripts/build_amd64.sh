#!/usr/bin/env bash
# Cross-compile a bot tree to a STATIC linux/amd64 binary, from an arm64 box
# with no Docker: zig cc is the cross C compiler (x86_64-linux-musl), nim and
# zig come from nixpkgs, and the dependency set is /workspace/.bot-deps --
# every repo in bot/nimby.lock at its pinned SHA, bitworld on the 8-bit-mask
# lineage the lock demands (protocols.nim's ButtonC tripwire fails the build
# otherwise).
#
#   build_amd64.sh <bot-dir> <out-binary>
#
# <bot-dir> is a full bot/ context (baseline.nim + baseline/), not a policy
# subtree. The flags mirror bot/Dockerfile.sandbox; --passL:-static is the one
# addition, and musl makes a fully static link safe (no glibc NSS trap).
set -euo pipefail

BOT_DIR="$(cd "$1" && pwd)"
mkdir -p "$(dirname "$2")"
OUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
DEPS=/workspace/.bot-deps
CACHE="${BUILD_AMD64_CACHE:-/tmp/bot-amd64-cache}"

[ -f "$BOT_DIR/baseline.nim" ] || { echo "$BOT_DIR has no baseline.nim" >&2; exit 1; }
[ -f "$DEPS/paths.cfg" ] || { echo "no $DEPS/paths.cfg -- clone bot deps first" >&2; exit 1; }

PATHS=()
while IFS= read -r line; do
  PATHS+=("$(echo "$line" | tr -d '"')")
done < "$DEPS/paths.cfg"

export PATH="$HOME/.local/bin:$PATH"
cd "$BOT_DIR"
nix shell nixpkgs#nim nixpkgs#zig -c nim c \
  --cpu:amd64 --os:linux \
  -d:release -d:useMalloc --opt:speed --stackTrace:on \
  --cc:clang --clang.exe:zigcc-amd64 --clang.linkerexe:zigcc-amd64 \
  --passL:-static \
  "${PATHS[@]}" \
  --hints:off --warning:UnusedImport:off \
  --nimcache:"$CACHE" \
  --out:"$OUT" \
  baseline.nim
echo "built $OUT (static linux/amd64)"
