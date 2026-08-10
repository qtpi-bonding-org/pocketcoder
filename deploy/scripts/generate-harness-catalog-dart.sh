#!/bin/sh
set -eu

catalog_file=${1:?harness catalog file is required}
output_file=${2:?Dart output file is required}

compact_catalog=$(jq -c . "$catalog_file")
tmp_file="$output_file.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT

{
  printf '%s\n' '// GENERATED FILE. DO NOT EDIT.'
  printf '%s\n' '// Source: deploy/release/harnesses.json'
  printf '%s\n' 'const bundledHarnessCatalogJson ='
  printf '%s\n' "    r'''$compact_catalog''';"
} > "$tmp_file"

mv "$tmp_file" "$output_file"
trap - EXIT
