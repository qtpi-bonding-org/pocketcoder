#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
flutter_package="$repo_root/client/packages/pocketcoder_flutter"
canonical_pb_schema="$repo_root/server/pocketbase/pb_migrations/schema.json"
flutter_pb_schema="$flutter_package/assets/pb_schema.json"
export_pocketbase=false

usage() {
  cat <<'EOF'
Usage: tooling/scripts/generate_flutter.sh [--export-pocketbase]

Regenerates every checked-in Dart contract used by the Flutter workspace:
  - OpenAPI Go types and the pocketcoder_api Dart package
  - PocketBase collection models and constants
  - Freezed, JSON, Injectable, and other build_runner outputs

By default the command is deterministic and uses the checked-in schemas. It
also verifies that the canonical backend schema and Flutter's exported schema
produce identical Dart collection contracts. Pass --export-pocketbase when a
local PocketBase is running and its live schema should replace the Flutter
asset before generation.
EOF
}

while (($# > 0)); do
  case "$1" in
    --export-pocketbase)
      export_pocketbase=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if "$export_pocketbase"; then
  "$repo_root/tooling/scripts/export_schema.sh"
fi

"$repo_root/tooling/scripts/generate_openapi.sh"

schema_check_dir="$(mktemp -d "${TMPDIR:-/tmp}/pocketcoder-schema-check.XXXXXX")"
trap 'rm -rf "$schema_check_dir"' EXIT

python3 "$flutter_package/scripts/generate_models.py" \
  --schema "$canonical_pb_schema" \
  --output "$schema_check_dir/canonical"
python3 "$flutter_package/scripts/generate_models.py" \
  --schema "$flutter_pb_schema" \
  --output "$schema_check_dir/exported"

if ! diff -ru "$schema_check_dir/canonical" "$schema_check_dir/exported"; then
  echo "PocketBase backend and Flutter schemas produce different Dart contracts." >&2
  echo "Run with --export-pocketbase after rebuilding the local PocketBase." >&2
  exit 1
fi

python3 "$flutter_package/scripts/generate_models.py" \
  --schema "$canonical_pb_schema" \
  --output "$flutter_package/lib/domain/models"

(
  cd "$flutter_package"
  dart run build_runner build --delete-conflicting-outputs
)

# l10n_key_resolver embeds the current wall-clock time even when its inputs are
# unchanged. Remove that non-semantic line so regeneration is reproducible and
# the CI clean-diff check can detect only real contract drift.
l10n_resolver="$flutter_package/lib/l10n/l10n_key_resolver.g.dart"
if [[ -f "$l10n_resolver" ]]; then
  perl -0pi -e 's/^\/\/ Generated at:.*\n//m' "$l10n_resolver"
fi

echo "Regenerated all Flutter contracts."
