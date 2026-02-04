# STAGE 1: The PocketBase (Go / PocketBase)
# ------------------------------------------------------------------------------
FROM golang:1.24-alpine AS pocketbase-builder

RUN apk add --no-cache git gcc musl-dev

WORKDIR /app

# 1. Prepare Environment
COPY backend/go.mod ./backend/
COPY backend/ ./backend/
WORKDIR /app/backend

# 2. Tidy and Download
RUN go mod tidy
RUN go mod download

# 3. Build Source
RUN CGO_ENABLED=0 go build -o pocketbase main.go

# ------------------------------------------------------------------------------
# STAGE 2: The Connector (Rust)
# ------------------------------------------------------------------------------
FROM rust:1.83-alpine AS connector-builder

RUN apk add --no-cache musl-dev gcc

WORKDIR /app

# 1. Build Dependencies (Cached)
COPY connector/Cargo.toml connector/Cargo.lock* ./
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release

# 2. Build Source
COPY connector/src ./src
RUN cargo build --release

# ------------------------------------------------------------------------------
# STAGE 3: Final Stage (PocketBase + Gateway)
# ------------------------------------------------------------------------------
FROM alpine:latest

RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl \
    tmux \
    tzdata \
    openssl

WORKDIR /app

# Copy PocketBase Binary
COPY --from=pocketbase-builder /app/backend/pocketbase /app/pocketbase

# Copy PocketBase Configs/Hooks
COPY backend/pb_migrations /app/pb_migrations
COPY backend/pb_public /app/pb_public

# Copy Connector (Rust Binary)
COPY --from=connector-builder /app/target/release/pocketcoder-gateway /app/pocketcoder-gateway

# Create a master entrypoint
COPY <<EOF /app/entrypoint.sh
#!/bin/bash

echo "🚀 Starting PocketBase..."
/app/pocketbase serve --http=0.0.0.0:8090 &

echo "⏳ Waiting for PocketBase to boot..."
n=0
until [ "\$n" -ge 30 ]
do
  curl -s http://localhost:8090/api/health > /dev/null && break
  n=\$((n+1))
  sleep 1
done

if [ "\$n" -ge 30 ]; then
  echo "❌ PocketBase failed to start in time."
  exit 1
fi

echo "✅ PocketBase is UP."
sleep 2

echo "Starting Gateway on :3001..."
/app/pocketcoder-gateway 2>&1
EOF

RUN chmod +x /app/entrypoint.sh

EXPOSE 8090 3001
CMD ["/app/entrypoint.sh"]
