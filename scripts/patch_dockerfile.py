#!/usr/bin/env python3
"""Rewrite a player Dockerfile so its build stage trusts this sandbox's egress proxy.

The sandbox terminates TLS at a local proxy, so any build step that fetches over
HTTPS (the Nim toolchain, the Nim package lock) fails certificate verification
inside a container. This inserts a CA install and the proxy environment into
every build stage, leaving the original Dockerfile untouched on disk.

The final runtime stage is left alone: it never reaches the network, and the CA
should not ship inside an image that will be uploaded.
"""

import re
import sys
from pathlib import Path

CA_IN_CONTEXT = "ccr-agent-proxy.crt"
PROXY = "http://127.0.0.1:34327"


def patch(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    stage_is_final = []

    # A stage is "final" when it is the last FROM in the file.
    from_idx = [i for i, ln in enumerate(lines) if re.match(r"\s*FROM\s", ln, re.I)]
    last_from = from_idx[-1] if from_idx else -1

    for i, ln in enumerate(lines):
        out.append(ln)
        if i in from_idx and i != last_from:
            out += [
                f"COPY {CA_IN_CONTEXT} /usr/local/share/ca-certificates/{CA_IN_CONTEXT}",
                f"ENV https_proxy={PROXY} HTTPS_PROXY={PROXY}",
                f"ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt",
                f"ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt",
                f"ENV GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt",
            ]
            stage_is_final.append(False)

    text = "\n".join(out)

    # Refresh the system trust store as soon as ca-certificates exists. The
    # stock Dockerfile installs it in its first apt layer.
    marker = "rm -rf /var/lib/apt/lists/*"
    pos = text.find(marker)
    if pos == -1:
        raise SystemExit("could not find the apt cleanup line to anchor the CA refresh")
    end = text.find("\n", pos)
    text = text[: end + 1] + "\nRUN update-ca-certificates\n" + text[end + 1 :]
    return text


if __name__ == "__main__":
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    dst.write_text(patch(src.read_text()))
    print(f"patched {src} -> {dst}")
