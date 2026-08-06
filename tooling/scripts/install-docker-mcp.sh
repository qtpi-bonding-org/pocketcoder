#!/bin/sh

# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# Shared docker-mcp plugin installer — used by opencode, sandbox, and mcp-gateway Dockerfiles.
set -e

VERSION="v0.43.3"
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
