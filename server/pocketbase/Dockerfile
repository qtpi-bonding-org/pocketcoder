# STAGE 1: The PocketBase (Go / PocketBase)
# ------------------------------------------------------------------------------
FROM golang:1.27.0-alpine AS pocketbase-builder

RUN apk add --no-cache git openssh-client gcc musl-dev

WORKDIR /app

# 1. Prepare Environment
COPY server/pocketbase/go.mod ./
COPY server/pocketbase/ ./
WORKDIR /app

# 2. Tidy and Download
RUN go mod tidy
RUN go mod download

# 3. Build Source
RUN CGO_ENABLED=0 go build -o pocketbase main.go
RUN CGO_ENABLED=0 go build -o git-materializer ./cmd/git-materializer

# ------------------------------------------------------------------------------
# STAGE 2: Final Stage (PocketBase Only)
# ------------------------------------------------------------------------------
FROM alpine:3.21

RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl \
    tzdata \
    openssl \
    sqlite \
    sqlite-dev \
    git \
    openssh-client

WORKDIR /app

# Copy PocketBase Binary
COPY --from=pocketbase-builder /app/pocketbase /app/pocketbase
COPY --from=pocketbase-builder /app/git-materializer /app/git-materializer

# Copy PocketBase Configs/Hooks
COPY server/pocketbase/pb_migrations /app/pb_migrations
COPY server/pocketbase/pb_public /app/pb_public

# Copy backup and restore scripts
COPY server/pocketbase/backup_db.sh /app/backup_db.sh
COPY server/pocketbase/restore_from_backup.sh /app/restore_from_backup.sh
RUN chmod +x /app/backup_db.sh /app/restore_from_backup.sh

# Copy and set entrypoint
COPY server/pocketbase/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8090
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/pocketbase", "serve", "--http=0.0.0.0:8090"]
