#!/bin/sh
set -eu

release=${1:?40-character release commit is required}
output=${2:?deployment artifact output path is required}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
catalog="$repo_root/deploy/release/harnesses.json"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

install -d "$stage/deploy/scripts" "$stage/deploy/release"
"$script_dir/resolve-release-compose.sh" \
  "$repo_root/docker-compose.yml" \
  "$stage/docker-compose.prebuilt.yml" \
  "$release" \
  "$catalog"

for file in \
  activate-release.sh \
  install-release-images.sh \
  prepare-runtime-env.sh \
  resolve-release-artifacts.sh \
  validate-release-contract.sh
do
  install -m 0755 "$script_dir/$file" "$stage/deploy/scripts/$file"
done
install -m 0644 "$catalog" "$stage/deploy/release/harnesses.json"
install -m 0644 "$repo_root/Caddyfile" "$stage/Caddyfile"

# Copy only Git-tracked runtime files. In particular, the generated
# server/mcp-gateway/config/mcp.env file is host state and must never enter a
# release artifact.
for path in \
  server/mcp-gateway/config \
  server/sqlpage/dashboard \
  deploy/tailscale/entrypoint.sh
do
  git -C "$repo_root" ls-files -- "$path"
done | while IFS= read -r file; do
  test -n "$file"
  install -d "$stage/$(dirname -- "$file")"
  install -m 0644 "$repo_root/$file" "$stage/$file"
done
chmod 0755 "$stage/deploy/tailscale/entrypoint.sh"

jq -n \
  --arg release "$release" \
  '{schemaVersion: 1, manifestSchemaVersion: 2, release: $release}' \
  > "$stage/release.json"

if find "$stage" -type f \( -name '.env' -o -name '*.key' -o -name '*.pem' \) \
  | grep -q .; then
  echo "deployment artifact contains a forbidden secret-bearing path" >&2
  exit 1
fi

tar -C "$stage" -czf "$output" .
