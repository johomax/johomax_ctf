#!/usr/bin/env bash
# Build the upstream starter playbook and its local Python runtime.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
engine_dir="${1:-/private/tmp/engine-main-v40}"
out_dir="${2:-$repo_root/episodes/s2-playbook}"
venv_dir="${S2_STARTER_VENV:-$repo_root/episodes/s2-starter-venv}"

if [ ! -f "$engine_dir/policies/starters/common/build_playbook.sh" ]; then
  echo "not an engine checkout with starter policies: $engine_dir" >&2
  exit 1
fi
if ! command -v docker >/dev/null; then
  echo "docker is required to build the wasi-sdk playbook" >&2
  exit 1
fi

mkdir -p "$out_dir"
out_dir="$(cd "$out_dir" && pwd)"
find "$out_dir" -maxdepth 1 -type f -name '*.wasm' -delete

# This is the starter Dockerfile's exact build base and wasi-sdk 33 recipe.
# Copying the read-only checkout inside the container avoids leaving .build
# artifacts in the human's upstream tree.
docker run --rm --platform linux/amd64 \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$engine_dir:/engine:ro" -v "$out_dir:/out" \
  nimlang/nim:2.2.6 /bin/bash -ceu '
    cp -a /engine /src
    archive=wasi-sdk-33.0-x86_64-linux.tar.gz
    curl -fsSL -o /tmp/wasi-sdk.tar.gz \
      "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-33/$archive"
    mkdir -p /opt/wasi-sdk
    tar -xzf /tmp/wasi-sdk.tar.gz --strip-components=1 -C /opt/wasi-sdk
    WASI_SDK_PATH=/opt/wasi-sdk \
      /src/policies/starters/common/build_playbook.sh /out
    chown -R "$HOST_UID:$HOST_GID" /out
  '

python_bin="${PYTHON:-python3}"
"$python_bin" -m venv "$venv_dir"
"$venv_dir/bin/pip" --disable-pip-version-check install "websockets>=13"

echo "starter playbook: $out_dir"
echo "starter python:   $venv_dir/bin/python"
