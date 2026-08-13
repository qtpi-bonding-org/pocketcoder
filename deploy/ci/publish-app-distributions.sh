#!/usr/bin/env bash
set -euo pipefail

document=${1:?app distributions JSON file is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_PUBLIC_BUCKET:-${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
schema="$repo_root/deploy/release/app-distributions.schema.json"

if [[ ! -f "$document" ]]; then
  echo "app distributions document not found: $document" >&2
  exit 1
fi

if ! jq -e . "$document" >/dev/null; then
  echo "app distributions document is not valid JSON: $document" >&2
  exit 1
fi

if command -v check-jsonschema >/dev/null 2>&1; then
  check-jsonschema --schemafile "$schema" "$document"
elif command -v jsonschema >/dev/null 2>&1; then
  jsonschema -i "$document" "$schema"
else
  echo "install check-jsonschema to validate app distribution data" >&2
  exit 1
fi

if ! jq -e '
  [
    .apps[]
    | .distributions[]
    | select(.status != "unavailable")
    | (.serverApiCompatibility.maximumVersion >=
       .serverApiCompatibility.minimumVersion)
  ]
  | all
' "$document" >/dev/null; then
  echo "an app distribution has an impossible server API range" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  digest=$(sha256sum "$document" | cut -d' ' -f1)
else
  digest=$(shasum -a 256 "$document" | cut -d' ' -f1)
fi

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
snapshot="app-distributions/$timestamp-$digest.json"
pointer=app-distributions.json

# Publish immutable history first. The mutable pointer moves only after the
# exact document has passed schema validation and its snapshot upload succeeds.
aws s3 cp "$document" "s3://$bucket/$snapshot" \
  --endpoint-url "$endpoint" \
  --content-type application/json \
  --cache-control 'public, max-age=31536000, immutable'

aws s3 cp "$document" "s3://$bucket/$pointer" \
  --endpoint-url "$endpoint" \
  --content-type application/json \
  --cache-control 'public, max-age=300'

printf 'Published app distributions:\n'
while IFS=$'\t' read -r app distributor status version build; do
  if [[ "$status" == unavailable ]]; then
    printf '  %s / %s: unavailable\n' "$app" "$distributor"
  else
    printf '  %s / %s: %s+%s (%s)\n' \
      "$app" "$distributor" "$version" "$build" "$status"
  fi
done < <(jq -r '
  .apps
  | to_entries[]
  | .key as $app
  | .value.distributions
  | to_entries[]
  | [$app, .key, .value.status, (.value.version // ""),
     ((.value.buildNumber // "") | tostring)]
  | @tsv
' "$document")
printf '  snapshot: s3://%s/%s\n' "$bucket" "$snapshot"
printf '  pointer:  s3://%s/%s\n' "$bucket" "$pointer"
