FROM rust:1.88-bookworm AS builder

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates clang cmake curl \
    && rm -rf /var/lib/apt/lists/*

ARG POCKET_MEMORY_MODEL_URL=""
ARG POCKET_MEMORY_MODEL_SHA256=""
ARG POCKET_MEMORY_REQUIRE_MODEL=0
RUN mkdir -p /out/models \
    && if [ -n "$POCKET_MEMORY_MODEL_URL" ] && [ -n "$POCKET_MEMORY_MODEL_SHA256" ]; then \
         curl --fail --location --retry 3 "$POCKET_MEMORY_MODEL_URL" \
           --output /out/models/multilingual-e5-small-q8_0.gguf; \
         printf '%s  %s\n' "$POCKET_MEMORY_MODEL_SHA256" \
           /out/models/multilingual-e5-small-q8_0.gguf | sha256sum --check --strict; \
       elif [ "$POCKET_MEMORY_REQUIRE_MODEL" = 1 ]; then \
         echo 'release build requires POCKET_MEMORY_MODEL_URL and POCKET_MEMORY_MODEL_SHA256' >&2; \
         exit 1; \
       fi
COPY server/memory/model/MIT-LICENSE.txt /out/models/MIT-LICENSE.txt
COPY server/memory/model/PROVENANCE.md /out/models/PROVENANCE.md

WORKDIR /src
COPY server/memory/Cargo.toml server/memory/Cargo.lock ./
COPY server/memory/schema.sql ./schema.sql
COPY server/memory/src ./src
RUN cargo build --locked --release

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl libstdc++6 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --home-dir /nonexistent --shell /usr/sbin/nologin pocket-memory \
    && mkdir -p /memory_data /models \
    && chown pocket-memory:pocket-memory /memory_data

COPY --from=builder /src/target/release/pocket-memory /usr/local/bin/pocket-memory
COPY --from=builder /out/models/ /models/

ARG POCKET_MEMORY_MODEL_SHA256="unbundled"
ENV POCKET_MEMORY_EMBEDDING_VERSION="intfloat-multilingual-e5-small-q8_0-v1:${POCKET_MEMORY_MODEL_SHA256}"

USER pocket-memory
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/pocket-memory"]
