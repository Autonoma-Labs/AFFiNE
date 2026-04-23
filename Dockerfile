# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS builder
WORKDIR /repo

ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV HUSKY=0
ENV NODE_OPTIONS=--max-old-space-size=8192
ENV PATH=/root/.cargo/bin:$PATH

ARG RUST_VERSION=1.87.0

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    openssl \
    pkg-config \
    python3 && \
  rm -rf /var/lib/apt/lists/*

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --default-toolchain ${RUST_VERSION}

COPY . .

RUN corepack enable
RUN yarn install --immutable

RUN yarn workspace @affine/server-native build

# The server bundle statically resolves every native fallback path in index.js.
# For Render we only execute one architecture at runtime, but all fallback names
# must exist during bundling.
RUN cp ./packages/backend/native/server-native.node ./packages/backend/native/server-native.x64.node && \
  cp ./packages/backend/native/server-native.node ./packages/backend/native/server-native.arm64.node && \
  cp ./packages/backend/native/server-native.node ./packages/backend/native/server-native.armv7.node

RUN yarn affine build -p @affine/web
RUN yarn affine build -p @affine/admin
RUN yarn affine build -p @affine/mobile
RUN yarn workspace @affine/server build

RUN yarn config set --json supportedArchitectures.cpu '["x64","arm64","arm"]' && \
  yarn config set --json supportedArchitectures.libc '["glibc"]'
RUN yarn workspaces focus @affine/server --production
RUN yarn workspace @affine/server prisma generate
RUN mv ./node_modules ./packages/backend/server

FROM node:22-bookworm-slim AS assets
WORKDIR /app

COPY --from=builder /repo/packages/backend/server /app
COPY --from=builder /repo/packages/frontend/apps/web/dist /app/static
COPY --from=builder /repo/packages/frontend/admin/dist /app/static/admin
COPY --from=builder /repo/packages/frontend/apps/mobile/dist /app/static/mobile
COPY --from=builder /repo/scripts/render-runtime.mjs /app/scripts/render-runtime.mjs

ARG TARGETARCH
ARG TARGETVARIANT

RUN apt-get update && \
  apt-get install -y --no-install-recommends openssl ca-certificates && \
  rm -rf /var/lib/apt/lists/*

RUN AFFINE_DOCKER_CLEAN=1 TARGETARCH="${TARGETARCH}" TARGETVARIANT="${TARGETVARIANT}" node ./scripts/docker-clean.mjs

FROM node:22-bookworm-slim
WORKDIR /app

COPY --from=assets /app /app

RUN apt-get update && \
  apt-get install -y --no-install-recommends openssl libjemalloc2 && \
  rm -rf /var/lib/apt/lists/*

ENV LD_PRELOAD=libjemalloc.so.2

EXPOSE 3010

CMD ["node", "./scripts/render-runtime.mjs", "start"]
