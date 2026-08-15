#!/bin/sh
# Dispatches an immutable candidate build for the checked-out integration
# branch. Public promotion is a separate workflow operation.
# Reads GH_TOKEN from the environment (injected
# by the secrets-daemon via `sops exec-env` -- never read from a file here,
# never echoed).
set -eu

ref=$(git symbolic-ref --short HEAD 2>/dev/null || true)
case "$ref" in main | staging) ;; *)
  echo "candidate builds require a checked-out main or staging branch" >&2
  exit 64
  ;;
esac

curl -sf -X POST \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions/workflows/nixos-image.yml/dispatches" \
  -d "{\"ref\":\"$ref\",\"inputs\":{\"operation\":\"build_candidate\"}}"

echo "candidate build dispatched: ref=$ref"
