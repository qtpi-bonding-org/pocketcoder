#!/bin/sh
# Dispatches an immutable candidate build against main. Public promotion is a
# separate workflow operation and is deliberately unavailable through this
# daemon action.
# Reads GH_TOKEN from the environment (injected
# by the secrets-daemon via `sops exec-env` -- never read from a file here,
# never echoed).
set -eu

curl -sf -X POST \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions/workflows/nixos-image.yml/dispatches" \
  -d '{"ref":"main","inputs":{"operation":"build_candidate"}}'

echo "candidate build dispatched"
