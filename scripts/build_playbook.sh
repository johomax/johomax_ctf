#!/usr/bin/env bash
# Compile and embed the Season 2 reference playbook.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
engine_dir="${CTF_ENGINE_DIR:-$repo_root/.engine}"
nim_bin="${NIM:-nim}"
plays=(edge_ride target_law supply_run bodyguard crossfire jackal)

if [[ ! -f "$engine_dir/play_sdk/play.nims" ]]; then
  echo "CTF_ENGINE_DIR must name a coworld-ctf checkout" >&2
  exit 1
fi

build_dir="$(mktemp -d /tmp/johomax-playbook.XXXXXX)"
trap 'rm -rf "$build_dir"' EXIT
cp -R "$engine_dir/play_sdk" "$build_dir/play_sdk"

if [[ -n "${WASI_SDK_PATH:-}" ]]; then
  toolchain="wasi-sdk at $WASI_SDK_PATH"
elif [[ -n "${ZIG:-}" ]]; then
  tool_dir="$build_dir/zig-wasi-sdk"
  mkdir -p "$tool_dir/bin" "$tool_dir/include"
  export ZIG_GLOBAL_CACHE_DIR="$build_dir/zig-global-cache"
  export ZIG_LOCAL_CACHE_DIR="$build_dir/zig-local-cache"
  cp "$script_dir/playbook_freestanding/string.h" "$tool_dir/include/string.h"
  cp "$script_dir/playbook_freestanding/builtins.c" "$tool_dir/builtins.c"
  "$ZIG" cc -target wasm32-freestanding -O3 -ffreestanding -fno-builtin \
    -fno-sanitize=all \
    -c "$tool_dir/builtins.c" -o "$tool_dir/builtins.o"
  cp "$script_dir/playbook_freestanding/clang" "$tool_dir/bin/clang"
  cp "$tool_dir/bin/clang" "$tool_dir/bin/clang++"
  chmod +x "$tool_dir/bin/clang" "$tool_dir/bin/clang++"
  export WASI_SDK_PATH="$tool_dir"
  toolchain="zig at $ZIG"
else
  echo "set WASI_SDK_PATH to wasi-sdk 33 or ZIG to a zig executable" >&2
  exit 1
fi

echo "building playbook with $toolchain"
for play in "${plays[@]}"; do
  echo "building $play"
  "$nim_bin" c -f --hints:off "$build_dir/play_sdk/reference/$play.nim"
  wasm="$build_dir/play_sdk/.build/$play.wasm"
  python3 "$script_dir/playbook_to_nim.py" "$wasm" \
    "$repo_root/bot/baseline/playbook_${play}.nim" --name "$play"
  size="$(wc -c < "$wasm" | tr -d ' ')"
  digest="$(shasum -a 256 "$wasm" | awk '{print $1}')"
  echo "$play $size bytes sha256=$digest"
done
