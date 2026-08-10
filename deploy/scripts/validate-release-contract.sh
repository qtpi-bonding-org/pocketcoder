#!/bin/sh
set -eu

manifest_file=${1:?release manifest file is required}
catalog_file=${2:?harness catalog file is required}

if ! jq -e '
  def exact_keys($expected):
    type == "object" and ((keys | sort) == ($expected | sort));
  . as $catalog |
  exact_keys(["schemaVersion", "defaultHarness", "harnesses"]) and
  .schemaVersion == 1 and
  (.defaultHarness | test("^[a-z0-9]+(?:-[a-z0-9]+)*$")) and
  (.harnesses | type == "array" and length > 0) and
  all(.harnesses[];
    exact_keys(["id", "composeService", "imageRepository"]) and
    (.id | test("^[a-z0-9]+(?:-[a-z0-9]+)*$")) and
    (.composeService | test("^[a-z0-9]+(?:-[a-z0-9]+)*$")) and
    (.imageRepository | test("^pocketcoder-[a-z0-9]+(?:-[a-z0-9]+)*$"))) and
  ([.harnesses[].id] | length == (unique | length)) and
  ([.harnesses[].composeService] | length == (unique | length)) and
  ([.harnesses[].imageRepository] | length == (unique | length)) and
  ([.harnesses[].id] | index($catalog.defaultHarness) != null)
' "$catalog_file" >/dev/null; then
  echo "invalid harness catalog: $catalog_file" >&2
  exit 1
fi

if ! jq -e --slurpfile catalog "$catalog_file" '
  def exact_keys($expected):
    type == "object" and ((keys | sort) == ($expected | sort));
  def artifact:
    . as $artifact |
    exact_keys(["url", "sha256", "bytes", "expandedBytes", "images"]) and
    (.url | type == "string" and startswith("https://")) and
    (.sha256 | type == "string" and test("^[0-9a-f]{64}$")) and
    (.bytes | type == "number" and . == floor and . > 0) and
    (.expandedBytes | type == "number" and . == floor and . >= $artifact.bytes) and
    (.images | type == "array") and
    all(.images[]; type == "string" and length > 0) and
    (.images | length == (unique | length));
  . as $manifest |
  ($catalog[0].harnesses | map(.id)) as $harness_ids |
  exact_keys([
    "schemaVersion", "release", "sourceUrl", "nixosImage", "deployment",
    "core", "harnesses", "optional"
  ]) and
  .schemaVersion == 2 and
  (.release | type == "string" and test("^[0-9a-f]{40}$")) and
  (.sourceUrl | type == "string" and endswith("/tree/" + $manifest.release)) and
  (.nixosImage | artifact and (.images | length == 0)) and
  (.deployment | artifact and (.images | length == 0)) and
  (.core | artifact and (.images | length > 0)) and
  (.harnesses | type == "object" and ((keys | sort) == ($harness_ids | sort))) and
  all(.harnesses[]; artifact and (.images | length > 0)) and
  (.optional | exact_keys(["ollama"])) and
  (.optional.ollama | artifact and (.images | length > 0)) and
  all($catalog[0].harnesses[];
    . as $harness |
    $manifest.harnesses[$harness.id].images
    | all(.[]; startswith($harness.imageRepository + ":")))
' "$manifest_file" >/dev/null; then
  echo "invalid release manifest v2: $manifest_file" >&2
  exit 1
fi
