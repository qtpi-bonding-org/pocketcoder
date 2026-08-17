#!/usr/bin/env bash
set -euo pipefail

source_commit=${1:?source commit is required}
nixos_metadata=${2:?NixOS metadata path is required}
artifact_metadata=${3:?release artifact metadata path is required}
output=${4:?canonical manifest output path is required}
document_output_dir=${5:-documents}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
cd "$repo_root"

case "$source_commit" in
  *[!0-9a-f]* | '') echo "invalid source commit" >&2; exit 1 ;;
esac
test "${#source_commit}" -eq 40
test "$(jq -r '.sourceCommit' "$artifact_metadata")" = "$source_commit"

server_version=${POCKETCODER_SERVER_VERSION:-1.0.0}
app_contract_version=${POCKETCODER_APP_CONTRACT_VERSION:-1}
server_api_version=${POCKETCODER_SERVER_API_VERSION:-1}
provisioning_contract_version=${POCKETCODER_PROVISIONING_CONTRACT_VERSION:-1}
deployment_contract_version=${POCKETCODER_DEPLOYMENT_CONTRACT_VERSION:-1}
minimum_source_contract=${POCKETCODER_MINIMUM_SOURCE_CONTRACT_VERSION:-1}
maximum_source_contract=${POCKETCODER_MAXIMUM_SOURCE_CONTRACT_VERSION:-1}
data_version=${POCKETCODER_DATA_VERSION:-1}
minimum_data_version=${POCKETCODER_MINIMUM_UPGRADE_DATA_VERSION:-1}
pro_minimum_version=${POCKETCODER_PRO_MINIMUM_VERSION:-1.0.0}
foss_minimum_version=${POCKETCODER_FOSS_MINIMUM_VERSION:-1.0.0}
base_url=${POCKETCODER_RELEASE_BASE:-https://images.relay.pocketcoder.org}
built_at=${POCKETCODER_BUILT_AT:-$(date -u '+%Y-%m-%dT%H:%M:%SZ')}

# configuration.nix's nixosVersion is the single source of truth for a live
# box's NIX_PATH pin; flake.nix's nixpkgs input has to independently repeat
# the same value as a static string literal (flake inputs can't reference a
# value computed by the module they build). Cross-check them here rather
# than trusting either alone -- see the "must be kept in sync" comments in
# both files.
configuration_nixos_version=$(grep -oE 'nixosVersion = "[0-9]{2}\.[0-9]{2}"' deploy/nixos/configuration.nix | grep -oE '[0-9]{2}\.[0-9]{2}')
flake_nixos_version=$(grep -oE 'nixpkgs\.url = "github:NixOS/nixpkgs/nixos-[0-9]{2}\.[0-9]{2}"' deploy/nixos/flake.nix | grep -oE '[0-9]{2}\.[0-9]{2}')
if [ -z "$configuration_nixos_version" ] || [ -z "$flake_nixos_version" ]; then
  echo "could not extract a NixOS version from configuration.nix and/or flake.nix" >&2
  exit 1
fi
if [ "$configuration_nixos_version" != "$flake_nixos_version" ]; then
  echo "configuration.nix (nixosVersion=$configuration_nixos_version) and flake.nix (nixpkgs.url=nixos-$flake_nixos_version) have drifted apart" >&2
  exit 1
fi
nixos_version=$configuration_nixos_version

mkdir -p "$document_output_dir"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

document_descriptor() {
  id=$1
  source_path=$2
  media_type=$3
  schema_version=${4:-}
  test -f "$source_path"
  sha=$(sha256_file "$source_path")
  bytes=$(wc -c < "$source_path" | tr -d ' ')
  case "$media_type" in
    application/json) extension=json ;;
    text/plain) extension=txt ;;
    text/x-shellscript) extension=sh ;;
    text/x-go) extension=go ;;
    *) echo "unsupported document media type: $media_type" >&2; exit 1 ;;
  esac
  cp "$source_path" "$document_output_dir/$sha.$extension"
  jq -n --arg id "$id" --arg mediaType "$media_type" \
    --arg sourcePath "$source_path" \
    --arg url "$base_url/v1/documents/$sha.$extension" \
    --arg sha256 "$sha" --argjson downloadBytes "$bytes" \
    --arg schemaVersion "$schema_version" '
      {id:$id, descriptor:({mediaType:$mediaType,sourcePath:$sourcePath,
        url:$url,sha256:$sha256,downloadBytes:$downloadBytes} +
        if $schemaVersion == "" then {}
        else {schemaVersion:($schemaVersion | tonumber)} end)}
    '
}

document_descriptor deployment-sizing deploy/release/deployment-sizing.json \
  application/json 1 > "$tmp_dir/document-sizing.json"
document_descriptor coding-harnesses deploy/release/harnesses.json \
  application/json 1 > "$tmp_dir/document-harnesses.json"
document_descriptor standard-linux-bootstrap \
  client/packages/pocketcoder_flutter/assets/deployment/standard_linux_bootstrap.sh \
  text/x-shellscript > "$tmp_dir/document-bootstrap.json"
document_descriptor standard-linux-caddy \
  client/packages/pocketcoder_flutter/assets/deployment/Caddyfile.template \
  text/plain > "$tmp_dir/document-caddy.json"
document_descriptor release-verifier deploy/release/verify-signed-payload.sh \
  text/x-shellscript > "$tmp_dir/document-verifier.json"
document_descriptor release-resolver deploy/scripts/resolve-signed-release.sh \
  text/x-shellscript > "$tmp_dir/document-resolver.json"
document_descriptor nixos-configuration deploy/nixos/configuration.nix \
  text/plain > "$tmp_dir/document-nixos-configuration.json"
document_descriptor nixos-bootstrap deploy/nixos/bootstrap.sh \
  text/x-shellscript > "$tmp_dir/document-nixos-bootstrap.json"
document_descriptor nixos-caddy deploy/nixos/caddy.nix \
  text/plain > "$tmp_dir/document-nixos-caddy.json"
document_descriptor runtime-environment deploy/scripts/prepare-runtime-env.sh \
  text/x-shellscript > "$tmp_dir/document-runtime-environment.json"
document_descriptor release-activation \
  deploy/release-manager/internal/release/activate.go \
  text/x-go > "$tmp_dir/document-release-activation.json"
document_descriptor docker-compose docker-compose.yml \
  text/plain > "$tmp_dir/document-docker-compose.json"

jq -s 'reduce .[] as $entry ({}; .[$entry.id] = $entry.descriptor)' \
  "$tmp_dir"/document-*.json > "$tmp_dir/documents.json"

jq -S -n \
  --arg serverVersion "$server_version" \
  --arg sourceCommit "$source_commit" \
  --arg builtAt "$built_at" \
  --arg proMinimumVersion "$pro_minimum_version" \
  --arg fossMinimumVersion "$foss_minimum_version" \
  --argjson appContractVersion "$app_contract_version" \
  --argjson serverApiVersion "$server_api_version" \
  --argjson provisioningContractVersion "$provisioning_contract_version" \
  --argjson deploymentContractVersion "$deployment_contract_version" \
  --argjson minimumSourceContract "$minimum_source_contract" \
  --argjson maximumSourceContract "$maximum_source_contract" \
  --argjson dataVersion "$data_version" \
  --argjson minimumDataVersion "$minimum_data_version" \
  --arg nixosVersion "$nixos_version" \
  --slurpfile documents "$tmp_dir/documents.json" \
  --slurpfile nixos "$nixos_metadata" \
  --slurpfile artifacts "$artifact_metadata" '
  {
    schemaVersion:1,
    serverVersion:$serverVersion,
    sourceRepository:"qtpi-bonding-org/pocketcoder",
    sourceCommit:$sourceCommit,
    builtAt:$builtAt,
    platform:{os:"linux",architecture:"amd64"},
    dataVersion:$dataVersion,
    minimumUpgradeFromDataVersion:$minimumDataVersion,
    compatibility:{
      app:{contractVersion:$appContractVersion,officialMinimumVersions:{
        "pocketcoder-pro":$proMinimumVersion,
        "pocketcoder-foss":$fossMinimumVersion}},
      server:{apiVersion:$serverApiVersion},
      workers:{"image-relay":1,"push-relay":1,"oauth-relay":1},
      provisioning:{contractVersion:$provisioningContractVersion},
      deployment:{contractVersion:$deploymentContractVersion,
        supportedSourceContractVersions:{minimum:$minimumSourceContract,
          maximum:$maximumSourceContract}},
      os:{nixosVersion:$nixosVersion}
    },
    documents:$documents[0],
    osImages:{
      nixos:{delivery:{kind:"artifact",artifact:$nixos[0]},
        bootstrap:{kind:"image-baked"}},
      debian:{delivery:{kind:"provider",providerImages:{linode:"linode/debian12"}},
        bootstrap:{kind:"generated-config",
          scriptDocument:"standard-linux-bootstrap",
          supportingDocuments:["standard-linux-caddy","release-verifier",
            "release-resolver"]}}
    },
    serverFiles:$artifacts[0].serverFiles,
    images:{
      required:$artifacts[0].images.required,
      choices:{"coding-harnesses":{
        schemaVersion:1,consumerPolicy:"required",
        catalogDocument:"coding-harnesses",minimumSelections:1,
        maximumSelections:($artifacts[0].images.choices["coding-harnesses"] | length),
        options:$artifacts[0].images.choices["coding-harnesses"]}},
      registry:$artifacts[0].images.registry
    }
  }
' > "$output"

"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$repo_root/deploy/release/release-manifest.schema.json" \
  "$output"
"$repo_root/deploy/scripts/validate-release-contract.sh" "$output" \
  "$repo_root/deploy/release/harnesses.json"
