#!/bin/sh
set -eu

compose_file=${1:?prebuilt Compose file is required}

# Validate the generated file with whichever Compose generation the host has.
# The Debian Standard Linux image currently ships docker-compose v1, whose
# `config --images` flag does not exist; keep image inventory extraction
# independent of that version-specific option.
if docker compose version >/dev/null 2>&1; then
  docker compose -f "$compose_file" config -q
elif docker-compose version >/dev/null 2>&1; then
  docker-compose -f "$compose_file" config -q
else
  echo "no supported Compose command found" >&2
  exit 1
fi

awk '$1 == "image:" { print $2 }' "$compose_file" | sort -u
