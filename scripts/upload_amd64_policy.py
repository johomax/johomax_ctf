#!/usr/bin/env python3
"""Upload a policy binary as a linux/amd64 image, with no Docker daemon.

The coworld CLI's `upload-policy` needs Docker for exactly three things: to
check the image exists, to read its ID, and to `docker image save` it into a
tar that the CLI then pushes blob-by-blob over plain HTTP. Everything after
the tar is daemon-free, so this script builds that tar directly -- one gzipped
layer holding the binary at /bin/baseline, a config declaring linux/amd64 --
and hands it to the same client code the CLI uses. The server assigns the
version; the printed ref is what identifies the build from here on.

The binary must be a static linux/amd64 executable (scripts/build_amd64.sh).
This machine is arm64, so a candidate is cross-compiled and smoke-tested under
qemu-x86_64 before it gets here.

Usage:
  uv run --no-project --with coworld==0.1.34 python \
      scripts/upload_amd64_policy.py <binary> -n <policy-name> \
      [--tag KEY=VALUE ...]
"""

import argparse
import gzip
import hashlib
import io
import json
import sys
import tarfile

from coworld.config import DEFAULT_SUBMIT_SERVER
from coworld.upload import (
    CoworldUploadClient,
    _push_archive_to_registry,
)


def build_docker_archive(binary: bytes) -> tuple[io.BytesIO, str]:
    """A docker-save archive holding one amd64 image, and its image ID."""
    # The layer: /bin/baseline, executable. diff_id hashes the UNCOMPRESSED
    # tar; the registry blob is the gzipped form. mtime=0 throughout so the
    # same binary always produces the same digests.
    layer = io.BytesIO()
    with tarfile.open(fileobj=layer, mode="w", format=tarfile.USTAR_FORMAT) as t:
        for name in ("bin", "workspace", "workspace/ctf"):
            d = tarfile.TarInfo(name)
            d.type = tarfile.DIRTYPE
            d.mode = 0o755
            t.addfile(d)
        f = tarfile.TarInfo("bin/baseline")
        f.mode = 0o755
        f.size = len(binary)
        t.addfile(f, io.BytesIO(binary))
    layer_bytes = layer.getvalue()
    diff_id = "sha256:" + hashlib.sha256(layer_bytes).hexdigest()
    layer_gz = gzip.compress(layer_bytes, mtime=0)

    config = json.dumps({
        "architecture": "amd64",
        "os": "linux",
        "config": {
            "Env": ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:"
                    "/usr/bin:/sbin:/bin"],
            "WorkingDir": "/workspace/ctf",
            "Cmd": ["/bin/baseline"],
        },
        "rootfs": {"type": "layers", "diff_ids": [diff_id]},
        "history": [{"created_by": "scripts/upload_amd64_policy.py"}],
    }, separators=(",", ":")).encode()
    image_id = "sha256:" + hashlib.sha256(config).hexdigest()

    archive = io.BytesIO()
    with tarfile.open(fileobj=archive, mode="w", format=tarfile.USTAR_FORMAT) as t:
        def add(name: str, data: bytes) -> None:
            info = tarfile.TarInfo(name)
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))
        add("config.json", config)
        add("layer.tar.gz", layer_gz)
        add("manifest.json", json.dumps([{
            "Config": "config.json",
            "RepoTags": [],
            "Layers": ["layer.tar.gz"],
        }]).encode())
    archive.seek(0)
    return archive, image_id


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("binary")
    ap.add_argument("-n", "--name", required=True)
    ap.add_argument("--tag", action="append", default=[])
    ap.add_argument("--server", default=DEFAULT_SUBMIT_SERVER)
    args = ap.parse_args()

    tags = dict(t.split("=", 1) for t in args.tag)
    with open(args.binary, "rb") as fh:
        binary = fh.read()
    if binary[:4] != b"\x7fELF" or binary[18:20] != b"\x3e\x00":
        sys.exit(f"{args.binary} is not an x86-64 ELF; refusing to upload")

    archive, image_id = build_docker_archive(binary)
    with CoworldUploadClient.from_login(server_url=args.server) as client:
        resp = client.request_image_upload(name=args.name, client_hash=image_id)
        if resp.pre_signed_info is not None:
            info = resp.pre_signed_info
            scheme = "http" if (info.endpoint_url or "").startswith("http://") \
                else "https"
            host, _, prefix = info.registry.partition("/")
            repository = f"{prefix}/{info.repository}" if prefix \
                else info.repository
            base_url = f"{scheme}://{host}/v2/{repository}"
            _push_archive_to_registry(archive, base_url, info.tag,
                                      info.authorization_token)
            image = client.complete_image_upload(resp.image.id)
        else:
            image = resp.image     # identical bytes already uploaded
        result = client.complete_docker_image_policy(
            name=args.name, container_image_id=image.id,
            run=None, secret_env=None, tags=tags or None)
    print(f"{result.name}:v{result.version}")


if __name__ == "__main__":
    main()
