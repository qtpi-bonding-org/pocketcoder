# Build stage
FROM golang:1.25-alpine AS builder

RUN apk add --no-cache git gcc musl-dev

WORKDIR /app

COPY . .
# Generate go.sum and download docs
RUN go mod tidy

# Build the custom pocketbase binary
RUN CGO_ENABLED=0 go build -o pocketbase main.go

# Final stage
FROM alpine:latest

RUN apk add --no-cache \
    unzip \
    ca-certificates \
    tzdata

WORKDIR /pb

# Copy the binary from the builder stage
COPY --from=builder /app/pocketbase /pb/pocketbase

# Copy static assets and hooks
COPY pb_migrations /pb/pb_migrations
COPY pb_hooks /pb/pb_hooks
COPY pb_public /pb/pb_public

# Copy entrypoint script
COPY entrypoint.sh /pb/entrypoint.sh
RUN chmod +x /pb/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/pb/entrypoint.sh"]
# Start PocketBase
CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8080"]
