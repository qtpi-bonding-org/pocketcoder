#!/bin/sh
set -eu

manifest_file=${1:?release manifest file is required}
catalog_file=${2:?harness catalog file is required}
declared_manifest_bytes=${3:-}
max_manifest_bytes=${POCKETCODER_MAX_MANIFEST_BYTES:-1048576}

fail() {
  echo "release contract: $1" >&2
  exit 1
}

check() {
  message=$1
  filter=$2
  if ! jq -e --slurpfile catalog "$catalog_file" "$filter" \
      "$manifest_file" >/dev/null; then
    fail "$message"
  fi
}

actual_manifest_bytes=$(wc -c < "$manifest_file" | tr -d ' ')
test "$actual_manifest_bytes" -le "$max_manifest_bytes" ||
  fail "manifest exceeds the 1 MiB pre-parse limit"
if test -n "$declared_manifest_bytes"; then
  test "$declared_manifest_bytes" -eq "$actual_manifest_bytes" ||
    fail "manifest downloadBytes does not match the fetched body"
fi

if ! jq -e '
  . as $catalog |
  .schemaVersion == 1 and
  (.defaultHarness | type == "string") and
  (.harnesses | type == "array" and length > 0) and
  all(.harnesses[];
    (.id | type == "string") and
    (.composeService | type == "string") and
    (.imageRepository | type == "string") and
    (.upstreamVersion | type == "string")) and
  ([.harnesses[].id] | length == (unique | length)) and
  ([.harnesses[].composeService] | length == (unique | length)) and
  ([.harnesses[].imageRepository] | length == (unique | length)) and
  ([.harnesses[].id] | index($catalog.defaultHarness) != null)
' "$catalog_file" >/dev/null; then
  fail "harness catalog identifiers must be unique and include the default"
fi

check "minimumUpgradeFromDataVersion exceeds dataVersion" '
  .minimumUpgradeFromDataVersion <= .dataVersion
'

check "deployment source contract range is invalid" '
  .compatibility.deployment as $deployment |
  $deployment.supportedSourceContractVersions.minimum <=
    $deployment.supportedSourceContractVersions.maximum and
  $deployment.contractVersion >=
    $deployment.supportedSourceContractVersions.minimum and
  $deployment.contractVersion <=
    $deployment.supportedSourceContractVersions.maximum
'

check "required Worker API versions are missing" '
  .compatibility.workers as $workers |
  all(["image-relay", "push-relay", "oauth-relay"][];
    ($workers[.] | type == "number" and . >= 1))
'

check "an artifact has impossible byte sizes" '
  [
    .serverFiles,
    (.osImages[].delivery | select(.kind == "artifact") | .artifact),
    .images.required[],
    .images.choices[].options[],
    .images.optional[]
  ] |
  all(.[]; .unpackedBytes >= .downloadBytes)
'

check "an immutable artifact URL is not content-addressed by its sha256" '
  [
    .serverFiles,
    (.osImages[].delivery | select(.kind == "artifact") | .artifact),
    .images.required[],
    .images.choices[].options[],
    .images.optional[]
  ] |
  all(.[]; . as $artifact |
    ($artifact.url | test("/" + $artifact.sha256 + "[.][A-Za-z0-9.]+$")))
'

check "a document URL is not content-addressed by its sha256" '
  all(.documents[]; . as $document |
    ($document.url | test("/" + $document.sha256 + "[.][A-Za-z0-9.]+$")))
'

check "a JSON document descriptor lacks a matching schemaVersion" '
  all(.documents[];
    if .mediaType == "application/json"
    then (.schemaVersion | type == "number" and . >= 1)
    else has("schemaVersion") | not
    end)
'

check "an OS bootstrap references a missing document" '
  .documents as $documents |
  all(.osImages[].bootstrap;
    if .kind == "generated-config"
    then $documents[.scriptDocument] != null and
      all(.supportingDocuments[]; $documents[.] != null)
    else true
    end)
'

check "a choice group has impossible selection bounds" '
  all(.images.choices[];
    .minimumSelections <= (.options | length) and
    (.maximumSelections == null or
      (.maximumSelections >= .minimumSelections and
       .maximumSelections <= (.options | length))))
'

check "a choice group references a missing catalog document" '
  .documents as $documents |
  all(.images.choices[];
    (has("catalogDocument") | not) or
    $documents[.catalogDocument] != null)
'

check "coding harness choices do not exactly match the harness catalog" '
  ($catalog[0].harnesses | map(.id) | sort) as $catalogIds |
  [
    .images.choices[] |
    select(.catalogDocument? == "coding-harnesses") |
    (.options | keys | sort)
  ] as $groups |
  ($groups | length) == 1 and $groups[0] == $catalogIds
'

check "a harness image does not match its catalog repository and source commit" '
  . as $manifest |
  (.images.choices[] |
    select(.catalogDocument? == "coding-harnesses") |
    .options) as $options |
  all($catalog[0].harnesses[];
    . as $harness |
    ($options[$harness.id].images | length) >= 1 and
    all($options[$harness.id].images[];
      . == ($harness.imageRepository + ":" + $manifest.sourceCommit)))
'

check "a Docker image identity occurs in more than one archive" '
  [
    .images.required[].images[],
    .images.choices[].options[].images[],
    .images.optional[].images[]
  ] as $images |
  ($images | length) == ($images | unique | length)
'

exit 0
