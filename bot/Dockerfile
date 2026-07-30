# The upstream build recipe, from coworld-ctf's players/baseline/Dockerfile.
# It expects the coworld-ctf PROJECT LAYOUT as build context
# (players/baseline/baseline.nim), not this archive's bot/ directory — lay the
# bot files into a coworld-ctf checkout to use it. In a Claude Code sandbox use
# Dockerfile.sandbox instead, which builds from this directory and knows about
# the egress proxy.
#
# There are no compile-time switches: the policy has exactly one behaviour.
#
# nimby.lock is load-bearing: its first line pins bitworld to 5d229ac
# (branch daveey/hd-client-pin), the only lineage whose input mask carries
# ButtonC (bit 128, the grenade throw). See README.md.
FROM debian:bookworm-slim AS build

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git && \
  rm -rf /var/lib/apt/lists/*

RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
    curl -fsSL \
      -o /usr/local/bin/nimby \
https://github.com/treeform/nimby/releases/download/0.1.26/nimby-Linux-X64; \
  elif [ "$(dpkg --print-architecture)" = "arm64" ]; then \
    curl -fsSL \
      -o /usr/local/bin/nimby \
https://github.com/treeform/nimby/releases/download/0.1.26/nimby-Linux-ARM64; \
  else \
    echo "unsupported arch: $(dpkg --print-architecture)" && exit 1; \
  fi && \
  chmod +x /usr/local/bin/nimby && \
  nimby use 2.2.4

ENV PATH="/root/.nimby/nim/bin:$PATH"

WORKDIR /workspace/ctf
COPY nimby.lock .
RUN nimby --global sync nimby.lock

COPY . .
RUN nim c \
  -d:release \
  -d:useMalloc \
  --opt:speed \
  --stackTrace:on \
  --nimcache:/tmp/ctf-nimcache \
  --out:baseline \
  players/baseline/baseline.nim

# Run Docker.
FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4 && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/ctf
COPY --from=build /workspace/ctf/baseline /bin/baseline

CMD ["/bin/baseline"]
