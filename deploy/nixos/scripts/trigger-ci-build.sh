#!/bin/sh
# Dispatches an immutable candidate build for the checked-out integration
# branch. Public promotion is a separate workflow operation.
# Reads GH_TOKEN from the environment (injected
# by the secrets-daemon via `sops exec-env` -- never read from a file here,
# never echoed).
#
# Usage: trigger-ci-build.sh [--attest-branch]
#
# --attest-branch is an explicit, non-default opt-in: it bakes
# POCKETCODER_GITHUB_WORKFLOW_BRANCH=<checked-out ref> into the built image
# (see deploy/nixos/release-branch.nix), so first-boot bootstrap trusts
# attestations published from that branch instead of main. Omit it (the
# default) for every normal build, including ordinary pushes to staging --
# the image always trusts main unless this is passed explicitly.
set -eu

attest_branch=false
case "${1:-}" in
  --attest-branch) attest_branch=true ;;
  '') ;;
  *) echo "usage: $0 [--attest-branch]" >&2; exit 64 ;;
esac

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
  -d "{\"ref\":\"$ref\",\"inputs\":{\"operation\":\"build_candidate\",\"attest_branch\":$attest_branch}}"

echo "candidate build dispatched: ref=$ref attest_branch=$attest_branch"
