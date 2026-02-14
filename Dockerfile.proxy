FROM rust:1.83-alpine AS builder
RUN apk add --no-cache musl-dev gcc
WORKDIR /app
COPY proxy/Cargo.toml proxy/Cargo.lock* ./
# Create dummy src/main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Now copy actual source and build app
COPY proxy/src ./src
# Touch main.rs to ensure rebuild
RUN touch src/main.rs
RUN cargo build --release

# Pinned to 3.17 to ensure TMUX 3.3a protocol compatibility with the Sandbox
FROM alpine:3.17
RUN apk add --no-cache ca-certificates tmux bash curl openssh-client
WORKDIR /app
COPY --from=builder /app/target/release/pocketcoder-proxy /app/pocketcoder
COPY --from=builder /app/target/release/pocketcoder-proxy /app/proxy_share/pocketcoder

# Create the share directory for the binary proxy tools
RUN mkdir -p /app/proxy_share && \
    printf '#!/bin/bash\n/app/pocketcoder shell "$@"\n' > /app/proxy_share/pocketcoder-shell && \
    chmod +x /app/proxy_share/pocketcoder-shell

# Default entrypoint for the proxy container (Server Mode)
ENTRYPOINT ["/app/pocketcoder"]
CMD ["server", "--port", "3001"]
