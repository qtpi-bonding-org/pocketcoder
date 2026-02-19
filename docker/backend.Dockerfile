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
# STAGE 2: Final Stage (PocketBase Only)
# ------------------------------------------------------------------------------
FROM alpine:latest

RUN apk add --no-cache \
    ca-certificates \
    bash \
    curl \
    tzdata \
    openssl \
    sqlite \
    sqlite-dev

WORKDIR /app

# Copy PocketBase Binary
COPY --from=pocketbase-builder /app/backend/pocketbase /app/pocketbase

# Copy PocketBase Configs/Hooks
COPY backend/pb_migrations /app/pb_migrations
COPY backend/pb_public /app/pb_public

# Copy backup and restore scripts
COPY backend/backup_db.sh /app/backup_db.sh
COPY backend/restore_from_backup.sh /app/restore_from_backup.sh
RUN chmod +x /app/backup_db.sh /app/restore_from_backup.sh

# Copy and set entrypoint
COPY backend/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8090
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/pocketbase", "serve", "--http=0.0.0.0:8090"]

