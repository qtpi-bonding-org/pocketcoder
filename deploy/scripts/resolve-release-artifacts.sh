#!/bin/sh
set -eu

manifest_file=${1:?release manifest file is required}
catalog_file=${2:?harness catalog file is required}
shift 2

if [ "$#" -eq 0 ]; then
  echo "at least one harness must be selected" >&2
  exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$script_dir/validate-release-contract.sh" "$manifest_file" "$catalog_file"

selected=$(printf '%s\n' "$@" | jq -Rsc 'split("\n")[:-1]')

if ! jq -en --argjson selected "$selected" --slurpfile catalog "$catalog_file" '
  ($catalog[0].harnesses | map(.id)) as $known |
  ($selected | length == (unique | length)) and
  all($selected[]; . as $id | $known | index($id) != null)
' >/dev/null; then
  echo "selected harnesses must be known and duplicate-free" >&2
  exit 1
fi

jq --argjson selected "$selected" --slurpfile catalog "$catalog_file" '
  . as $manifest |
  (.images.choices[] |
    select(.catalogDocument? == "coding-harnesses") |
    .options) as $harnesses |
  [
    {kind: "server-files", id: "server-files", artifact: $manifest.serverFiles}
  ] + [
    $manifest.images.required | to_entries[] |
    {kind: "required", id: .key, artifact: .value}
  ] + [
    $catalog[0].harnesses[]
    | select(.id as $id | $selected | index($id) != null)
    | {kind: "choice", group: "coding-harnesses", id: .id,
       artifact: $harnesses[.id]}
  ]
' "$manifest_file"
