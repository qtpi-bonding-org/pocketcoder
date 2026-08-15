#!/bin/sh
set -eu

usage() {
  echo "usage: $0 <provision-handoff.json> <expected-digest> <expected-source-commit> <expected-channel-sequence>" >&2
  exit 64
}

[ "$#" -eq 4 ] || usage

handoff=$1
expected_digest=$2
expected_source_commit=$3
expected_sequence=$4
release_branch=${POCKETCODER_VPS_SCRIPT_RELEASE_BRANCH:-main}
case "$release_branch" in
  main|staging) ;;
  *) echo "release branch must be main or staging" >&2; exit 64 ;;
esac

[ -f "$handoff" ] || { echo "handoff file does not exist" >&2; exit 1; }
case "$expected_digest" in
  *[!0-9a-f]* | '') echo "expected digest must be a SHA-256" >&2; exit 1 ;;
esac
[ "${#expected_digest}" -eq 64 ] || { echo "expected digest must be a SHA-256" >&2; exit 1; }
case "$expected_source_commit" in
  *[!0-9a-f]* | '') echo "expected source commit must be lowercase hexadecimal" >&2; exit 1 ;;
esac
[ "${#expected_source_commit}" -eq 40 ] || {
  echo "expected source commit must be 40 characters" >&2
  exit 1
}
case "$expected_sequence" in
  '' | *[!0-9]*) echo "expected channel sequence must be a positive integer" >&2; exit 1 ;;
esac
[ "$expected_sequence" -gt 0 ] || {
  echo "expected channel sequence must be positive" >&2
  exit 1
}

host=$(jq -er '.ipAddress | strings | select(test("^[0-9a-fA-F:.]+$"))' "$handoff")
hostname=$(jq -er '.hostname | strings | select(test("^[A-Za-z0-9.-]+$"))' "$handoff")
key_path=$(jq -er '.sshPrivateKeyPath | strings | select(startswith("/"))' "$handoff")
initial_digest=$(jq -er '.releaseDigest | strings | select(test("^[0-9a-f]{64}$"))' "$handoff")
initial_source_commit=$(jq -er '.sourceCommit | strings | select(test("^[0-9a-f]{40}$"))' "$handoff")
initial_sequence=$(jq -er '.sequence | numbers | select(. > 0)' "$handoff")

[ -f "$key_path" ] || { echo "retained test SSH key does not exist" >&2; exit 1; }
[ "$initial_digest" != "$expected_digest" ] || {
  echo "the expected release must differ from the provisioned release" >&2
  exit 1
}

ssh_base() {
  ssh -q -i "$key_path" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=15 \
    "root@$host" "$@"
}

echo "VPS SCRIPT UPDATE: asserting provisioned release $initial_source_commit (sequence $initial_sequence)"
initial_manager_sha=$(ssh_base 'sha256sum /opt/pocketcoder/current/bin/pocketcoder-release | cut -d" " -f1')
ssh_base "set -eu
  test \"\$(jq -r .releaseDigest /var/lib/pocketcoder/release/current.json)\" = \"$initial_digest\"
  test \"\$(jq -r .sourceCommit /var/lib/pocketcoder/release/current.json)\" = \"$initial_source_commit\"
  test \"\$(jq -r .channelSequence /var/lib/pocketcoder/release/current.json)\" = \"$initial_sequence\"
  test -x /opt/pocketcoder/current/bin/pocketcoder-release"

echo "VPS SCRIPT UPDATE: invoking the same native command used by the Flutter OS-control service"
ssh_base "set -eu; POCKETCODER_GITHUB_WORKFLOW_BRANCH=$release_branch /opt/pocketcoder/current/bin/pocketcoder-release update"

echo "VPS SCRIPT UPDATE: asserting activated release $expected_source_commit (sequence $expected_sequence)"
ssh_base "set -eu
  test \"\$(jq -r .releaseDigest /var/lib/pocketcoder/release/current.json)\" = \"$expected_digest\"
  test \"\$(jq -r .sourceCommit /var/lib/pocketcoder/release/current.json)\" = \"$expected_source_commit\"
  test \"\$(jq -r .channel /var/lib/pocketcoder/release/current.json)\" = nightly
  test \"\$(jq -r .channelSequence /var/lib/pocketcoder/release/current.json)\" = \"$expected_sequence\"
  test \"\$(readlink /opt/pocketcoder/current)\" = \"/opt/pocketcoder/releases/$expected_digest\"
  test -x /opt/pocketcoder/current/bin/pocketcoder-release
  test \"\$(docker ps --format '{{.Names}}' | grep -c '^pocketcoder-' || true)\" -gt 0"

final_manager_sha=$(ssh_base 'sha256sum /opt/pocketcoder/current/bin/pocketcoder-release | cut -d" " -f1')
test -n "$initial_manager_sha"
test -n "$final_manager_sha"
echo "VPS SCRIPT UPDATE: release-manager binary $initial_manager_sha -> $final_manager_sha"

curl --fail --silent --show-error --max-time 30 \
  --resolve "$hostname:443:$host" \
  "https://$hostname/api/health" >/dev/null

echo "VPS SCRIPT UPDATE: passed $initial_source_commit -> $expected_source_commit"
