#!/usr/bin/env bash
# Build a bot tree into a STATIC linux/amd64 binary, with no Docker.
#
#   build_amd64.sh <bot-dir> <out-binary>
#
# <bot-dir> is a full bot/ context (baseline.nim + baseline/), not a policy
# subtree. The flags mirror bot/Dockerfile.sandbox; --passL:-static is the one
# addition, and musl makes a fully static link safe (no glibc NSS trap).
#
# zig cc is the C compiler either way -- it targets x86_64-linux-musl whether
# or not the host is x86_64, so one recipe produces one binary on both boxes
# this loop has run on. What differs is where nim and zig come from:
#
#   - nix on PATH  : `nix shell nixpkgs#nim nixpkgs#zig`, the sandbox arm64 box.
#   - otherwise    : nim and zig are expected ON PATH already, which is the
#                    plain-Ubuntu case (nimby installs nim, zig comes from its
#                    own tarball). $CTF_TOOLS_BIN is prepended if set.
#
# The dependency set is $CTF_BOT_DEPS (default /workspace/.bot-deps): every
# repo in bot/nimby.lock at its pinned SHA, bitworld on the 8-bit-mask lineage
# the lock demands (protocols.nim's ButtonC tripwire fails the build
# otherwise). scripts/sync_deps.sh writes it.
set -euo pipefail

BOT_DIR="$(cd "$1" && pwd)"
mkdir -p "$(dirname "$2")"
OUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
DEPS="${CTF_BOT_DEPS:-/workspace/.bot-deps}"
CACHE="${BUILD_AMD64_CACHE:-/tmp/bot-amd64-cache}"

[ -f "$BOT_DIR/baseline.nim" ] || { echo "$BOT_DIR has no baseline.nim" >&2; exit 1; }
[ -f "$DEPS/paths.cfg" ] || { echo "no $DEPS/paths.cfg -- run scripts/sync_deps.sh" >&2; exit 1; }

PATHS=()
while IFS= read -r line; do
  PATHS+=("$(echo "$line" | tr -d '"')")
done < "$DEPS/paths.cfg"

export PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd):${CTF_TOOLS_BIN:-$HOME/.local/bin}:$HOME/.nimby/nim/bin:$PATH"

NIM=(nim)
if command -v nix >/dev/null 2>&1; then
  NIM=(nix shell nixpkgs#nim nixpkgs#zig -c nim)
else
  command -v nim >/dev/null || { echo "no nim on PATH and no nix to fetch one" >&2; exit 1; }
  command -v zig >/dev/null || { echo "no zig on PATH and no nix to fetch one" >&2; exit 1; }
fi

cd "$BOT_DIR"
"${NIM[@]}" c \
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
