#!/bin/bash

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
set -e

# Post-install: generate .env from Elestio-provided environment variables
cat > .env <<EOF
POCKETBASE_SUPERUSER_EMAIL=${POCKETBASE_SUPERUSER_EMAIL}
POCKETBASE_SUPERUSER_PASSWORD=${POCKETBASE_SUPERUSER_PASSWORD}
POCKETBASE_ADMIN_EMAIL=${POCKETBASE_ADMIN_EMAIL}
POCKETBASE_ADMIN_PASSWORD=${POCKETBASE_ADMIN_PASSWORD}
AGENT_EMAIL=${AGENT_EMAIL}
AGENT_PASSWORD=${AGENT_PASSWORD}
OPEN_NOTEBOOK_ENCRYPTION_KEY=${OPEN_NOTEBOOK_ENCRYPTION_KEY}
PN_PROVIDER=${PN_PROVIDER}
PN_URL=${PN_URL}
PN_RELAY_SECRET=${PN_RELAY_SECRET}
EOF

docker compose up -d
