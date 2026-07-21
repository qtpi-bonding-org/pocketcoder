# Shared Rust builder stage for pocketcoder-proxy
# This eliminates the need for runtime volume coordination
FROM rust:1.83-alpine AS rust-builder

RUN apk add --no-cache musl-dev gcc

WORKDIR /build

# Copy dependency manifests
COPY dormant/proxy/Cargo.toml dormant/proxy/Cargo.lock* ./

# Create dummy src to cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Copy actual source and build
COPY dormant/proxy/src ./src
RUN touch src/main.rs
RUN cargo build --release

# Binary is now at /build/target/release/pocketcoder-proxy
