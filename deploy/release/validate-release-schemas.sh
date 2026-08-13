#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
schema_validator=${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}

command -v "$schema_validator" >/dev/null 2>&1 || {
  echo "check-jsonschema is required; install deploy/release/requirements.txt" >&2
  exit 1
}

validate() {
  schema=$1
  instance=$2
  "$schema_validator" --schemafile "$script_dir/$schema" "$script_dir/$instance"
}

validate release-manifest.schema.json release-manifest.example.json
validate release-channel-pointer.schema.json release-channel-pointer.example.json
validate release-revocation.schema.json release-revocation.example.json
validate harnesses.schema.json harnesses.json
validate deployment-sizing.schema.json deployment-sizing.json
