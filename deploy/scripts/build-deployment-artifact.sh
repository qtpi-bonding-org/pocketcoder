#!/bin/sh
set -eu

release=${1:?40-character release commit is required}
output=${2:?deployment artifact output path is required}
server_version=${POCKETCODER_SERVER_VERSION:-1.0.0}
server_api_version=${POCKETCODER_SERVER_API_VERSION:-1}
data_version=${POCKETCODER_DATA_VERSION:-1}
deployment_contract_version=${POCKETCODER_DEPLOYMENT_CONTRACT_VERSION:-1}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
catalog="$repo_root/deploy/release/harnesses.json"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

install -d "$stage/bin" "$stage/deploy/scripts"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go -C \
  "$repo_root/deploy/release-manager" build -trimpath \
  -ldflags "-s -w -X main.version=$server_version" \
  -o "$stage/bin/pocketcoder-release" ./cmd/pocketcoder-release
"$script_dir/resolve-release-compose.sh" \
  "$repo_root/docker-compose.yml" \
  "$stage/docker-compose.prebuilt.yml" \
  "$release" \
  "$catalog"

for file in \
  install-release-metadata-timer.sh \
  prepare-runtime-env.sh
do
  install -m 0755 "$script_dir/$file" "$stage/deploy/scripts/$file"
done
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
  --arg serverVersion "$server_version" \
  --arg sourceCommit "$release" \
  --argjson serverApiVersion "$server_api_version" \
  --argjson dataVersion "$data_version" \
  --argjson deploymentContractVersion "$deployment_contract_version" \
  '{schemaVersion: 1, serverVersion: $serverVersion,
    sourceCommit: $sourceCommit, serverApiVersion: $serverApiVersion,
    dataVersion: $dataVersion,
    deploymentContractVersion: $deploymentContractVersion}' \
  > "$stage/release.json"

if find "$stage" -type f \( -name '.env' -o -name '*.key' -o -name '*.pem' \) \
  | grep -q .; then
  echo "deployment artifact contains a forbidden secret-bearing path" >&2
  exit 1
fi

tar -C "$stage" -czf "$output" .
