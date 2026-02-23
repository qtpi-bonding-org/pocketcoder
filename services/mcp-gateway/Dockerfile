# MCP Gateway container - runs docker-mcp gateway process
FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    curl \
    docker-cli \
    ca-certificates

# Download and install docker-mcp binary (pinned version v0.39.3, multi-arch)
RUN ARCH=$(uname -m) && \
    case $ARCH in \
      x86_64)  M_ARCH="amd64" ;; \
      aarch64) M_ARCH="arm64" ;; \
      *)       M_ARCH="amd64" ;; \
    esac && \
    VERSION="v0.39.3" && \
    curl -L "https://github.com/docker/mcp-gateway/releases/download/${VERSION}/docker-mcp-linux-${M_ARCH}.tar.gz" -o /tmp/docker-mcp.tar.gz && \
    tar -xzf /tmp/docker-mcp.tar.gz -C /tmp && \
    mkdir -p /usr/local/lib/docker/cli-plugins/ && \
    mv /tmp/docker-mcp /usr/local/lib/docker/cli-plugins/docker-mcp && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-mcp && \
    rm /tmp/docker-mcp.tar.gz

# Set environment variable for container detection
ENV DOCKER_MCP_IN_CONTAINER=1

# Copy entrypoint script
COPY services/mcp-gateway/mcp-gateway-entrypoint.sh /mcp-gateway-entrypoint.sh
RUN chmod +x /mcp-gateway-entrypoint.sh

# Set working directory
WORKDIR /root

# Entrypoint script
ENTRYPOINT ["/mcp-gateway-entrypoint.sh"]