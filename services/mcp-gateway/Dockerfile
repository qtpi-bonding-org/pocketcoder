# MCP Gateway container - runs docker-mcp gateway process
FROM alpine:3.21

# Install required packages
RUN apk add --no-cache \
    curl \
    docker-cli \
    ca-certificates

# Install docker-mcp plugin (shared script, pinned version)
COPY scripts/install-docker-mcp.sh /tmp/install-docker-mcp.sh
RUN /tmp/install-docker-mcp.sh && rm /tmp/install-docker-mcp.sh

# Set environment variable for container detection
ENV DOCKER_MCP_IN_CONTAINER=1

# Copy entrypoint script
COPY services/mcp-gateway/mcp-gateway-entrypoint.sh /mcp-gateway-entrypoint.sh
RUN chmod +x /mcp-gateway-entrypoint.sh

# Set working directory
WORKDIR /root

# Entrypoint script
ENTRYPOINT ["/mcp-gateway-entrypoint.sh"]