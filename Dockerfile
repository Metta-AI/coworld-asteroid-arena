# Build Docker.
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

WORKDIR /workspace/cogame-asteroid-arena
COPY asteroid_arena.nimble .
RUN nimble refresh && \
  nimble install -y https://github.com/Metta-AI/bitworld.git && \
  nimble install -y --depsOnly

COPY . .
RUN mkdir -p /workspace/bitworld-assets && \
  bitworld_path="$(nimble path bitworld | head -n 1)" && \
  cp -R "$bitworld_path/client" /workspace/bitworld-assets/client

ARG NimFlags="-d:release -d:useMalloc --opt:speed --stackTrace:on"
ARG NimCommand="c"
ARG NimMain="src/asteroid_arena.nim"
RUN bitworld_path="$(nimble path bitworld | head -n 1)" && \
  nim $NimCommand \
  $NimFlags \
  --path:"$bitworld_path" \
  --path:src \
  --nimcache:/tmp/cogame-nimcache \
  --out:/bin/asteroid_arena \
  $NimMain

# Run Docker.
FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates curl && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/cogame-asteroid-arena
COPY --from=build /bin/asteroid_arena /bin/asteroid_arena
COPY --from=build /workspace/bitworld-assets/client ./client
COPY coworld_manifest.json .

CMD ["/bin/asteroid_arena", "--address:0.0.0.0", "--port:8080"]
