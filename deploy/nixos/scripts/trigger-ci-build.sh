#!/bin/sh
# Dispatches the "Build NixOS Image" GitHub Actions workflow against
# goose-agui-refactor-plan. Reads GH_TOKEN from the environment (injected
# by the secrets-daemon via `sops exec-env` -- never read from a file here,
# never echoed).
set -eu

curl -sf -X POST \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions/workflows/nixos-image.yml/dispatches" \
  -d '{"ref":"goose-agui-refactor-plan"}'

echo "dispatched"
