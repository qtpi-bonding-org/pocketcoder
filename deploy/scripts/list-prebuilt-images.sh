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

awk '
  function flush_service() {
    if (service != "" && !profiled && image != "") {
      print image
    }
  }
  # Compose v1 includes profile-only services in `config`, unlike Compose v2.
  # Track the whole service block so an image seen before its profiles stanza
  # is still excluded.
  /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
    flush_service()
    service = $1
    sub(/:$/, "", service)
    image = ""
    profiled = 0
    next
  }
  service != "" && $1 == "image:" { image = $2 }
  service != "" && $1 == "profiles:" { profiled = 1 }
  END { flush_service() }
' "$compose_file" | sort -u
