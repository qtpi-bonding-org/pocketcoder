#!/usr/bin/env bash
set -euo pipefail

# Verify the PocketBase schema inputs and checked-in Dart collection contracts
# without rewriting the working tree. Full OpenAPI regeneration remains the
# responsibility of generate_flutter.sh (and the generated-contract CI job).
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
model_generator="$repo_root/client/packages/pocketcoder_flutter/scripts/generate_models.py"
canonical_schema="$repo_root/server/pocketbase/pb_migrations/schema.json"
exported_schema="$repo_root/client/packages/pocketcoder_flutter/assets/pb_schema.json"
checked_in_models="$repo_root/client/packages/pocketcoder_flutter/lib/domain/models"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/pocketcoder-pb-contracts.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT

python3 "$model_generator" --schema "$canonical_schema" --output "$check_dir/canonical" >/dev/null
python3 "$model_generator" --schema "$exported_schema" --output "$check_dir/exported" >/dev/null

if ! diff -ru "$check_dir/canonical" "$check_dir/exported"; then
  echo "PocketBase canonical and exported schemas produce different Dart contracts." >&2
  echo "Run tooling/scripts/generate_flutter.sh --export-pocketbase against the local deployment." >&2
  exit 1
fi

# Compare only files owned by generate_models.py. The remaining model files
# are application-specific Freezed models and are intentionally out of scope.
if ! diff -ru "$check_dir/canonical" "$checked_in_models" \
  --exclude='*.freezed.dart' \
  --exclude='*.g.dart' \
  --exclude='file_entry.dart' \
  --exclude='message.dart' \
  --exclude='ollama_model.dart' \
  --exclude='permission.dart' \
  --exclude='poco_config.dart' \
  --exclude='tool_permission.dart'; then
  echo "Checked-in PocketBase Dart collection models are stale." >&2
  echo "Run tooling/scripts/generate_flutter.sh to regenerate them." >&2
  exit 1
fi

echo "PocketBase schema and generated Dart collection contracts are synchronized."
