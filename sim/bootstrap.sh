#!/usr/bin/env bash
# One-time setup for the local simulator: a Nim toolchain, the dependency set
# the engine pins, and a coworld-ctf checkout at sim/engine.pin.
#
# Everything it writes is gitignored and re-fetchable: ~/.nimby (toolchain and
# packages) and .engine/ (the engine checkout). Re-running is cheap and
# idempotent; run it again after moving the pin.
#
# Honours CTF_ENGINE_DIR if you already have a checkout you would rather use --
# in that case it only checks the commit and syncs dependencies, and will not
# touch your working tree.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SIM_DIR/.." && pwd)"

ENGINE_REPO="$(awk '$1 == "repo"   { print $2 }' "$SIM_DIR/engine.pin")"
ENGINE_COMMIT="$(awk '$1 == "commit" { print $2 }' "$SIM_DIR/engine.pin")"
ENGINE_DIR="${CTF_ENGINE_DIR:-$REPO_DIR/.engine}"
NIMBY_VERSION="${NIMBY_VERSION:-0.1.26}"
NIM_VERSION="${NIM_VERSION:-2.2.4}"

echo "== engine pin: $ENGINE_COMMIT"

# --- Nim toolchain ----------------------------------------------------------
# Same nimby release and Nim version the engine's and the bot's Dockerfiles
# use, so a local build and a container build agree on the compiler.
export PATH="$HOME/.nimby/nim/bin:$PATH"
if ! command -v nim >/dev/null; then
  echo "== installing nim $NIM_VERSION via nimby $NIMBY_VERSION"
  if ! command -v nimby >/dev/null; then
    NIMBY_BIN="${NIMBY_BIN:-/usr/local/bin/nimby}"
    ARCH="$(uname -m)"
    case "$ARCH" in
      x86_64)  NIMBY_ASSET=nimby-Linux-X64 ;;
      aarch64|arm64) NIMBY_ASSET=nimby-Linux-ARM64 ;;
      *) echo "unsupported arch: $ARCH" >&2; exit 1 ;;
    esac
    curl -fsSL -o "$NIMBY_BIN" \
      "https://github.com/treeform/nimby/releases/download/$NIMBY_VERSION/$NIMBY_ASSET"
    chmod +x "$NIMBY_BIN"
  fi
  nimby use "$NIM_VERSION"
fi
echo "== nim: $(nim --version | head -1)"

# --- engine checkout --------------------------------------------------------
if [ -n "${CTF_ENGINE_DIR:-}" ]; then
  echo "== using CTF_ENGINE_DIR=$ENGINE_DIR (not modifying it)"
  HAVE="$(git -C "$ENGINE_DIR" rev-parse HEAD)"
  if [ "$HAVE" != "$ENGINE_COMMIT" ]; then
    echo "   WARNING: checkout is at $HAVE, pin wants $ENGINE_COMMIT."
    echo "   Results from this build are not comparable to the pinned engine."
  fi
else
  if [ ! -d "$ENGINE_DIR/.git" ]; then
    echo "== cloning $ENGINE_REPO"
    git clone --filter=blob:none "$ENGINE_REPO" "$ENGINE_DIR"
  fi
  if [ "$(git -C "$ENGINE_DIR" rev-parse HEAD 2>/dev/null)" != "$ENGINE_COMMIT" ]; then
    echo "== checking out $ENGINE_COMMIT"
    git -C "$ENGINE_DIR" fetch --filter=blob:none origin "$ENGINE_COMMIT" 2>/dev/null \
      || git -C "$ENGINE_DIR" fetch origin
    git -C "$ENGINE_DIR" checkout --detach "$ENGINE_COMMIT"
  fi
fi

# --- dependencies -----------------------------------------------------------
# Sync the ENGINE's lock, not the bot's. They differ on exactly one line --
# bitworld -- and one binary can only hold one of them. The engine's pin is the
# right one twice over: it is what the hosted server is built from, and it is
# the lineage that merged the 8-bit input mask, so the policy's ButtonC
# tripwire passes against it. Nothing here rewrites bot/nimby.lock, which stays
# the tournament build's pin.
echo "== syncing engine dependencies"
(cd "$ENGINE_DIR" && nimby --global sync nimby.lock >/dev/null)

echo
echo "ready."
echo "  engine : $ENGINE_DIR"
echo "  nim    : $(command -v nim)"
echo
echo "next: python3 scripts/local_sim.py selfcheck"
