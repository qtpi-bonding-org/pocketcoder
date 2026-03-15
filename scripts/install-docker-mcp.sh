#!/bin/sh
# Shared docker-mcp plugin installer — used by opencode, sandbox, and mcp-gateway Dockerfiles.
set -e

VERSION="v0.39.3"
ARCH=$(uname -m)

case $ARCH in
  x86_64)  M_ARCH="amd64" ;;
  aarch64) M_ARCH="arm64" ;;
  *)       M_ARCH="amd64" ;;
esac

curl -L "https://github.com/docker/mcp-gateway/releases/download/${VERSION}/docker-mcp-linux-${M_ARCH}.tar.gz" -o /tmp/docker-mcp.tar.gz
tar -xzf /tmp/docker-mcp.tar.gz -C /tmp
mkdir -p /usr/local/lib/docker/cli-plugins/
mv /tmp/docker-mcp /usr/local/lib/docker/cli-plugins/docker-mcp
chmod +x /usr/local/lib/docker/cli-plugins/docker-mcp
rm /tmp/docker-mcp.tar.gz
