#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
spec="$repo_root/api/openapi/pocketcoder.yaml"
versions="$repo_root/api/openapi/generator-versions.env"

if [[ ! -f "$spec" || ! -f "$versions" ]]; then
  echo "OpenAPI contract inputs are missing" >&2
  exit 1
fi

# The script deliberately refuses floating tool versions. Install these exact
# versions in the developer environment before enabling generation outputs.
source "$versions"
require_version() {
  local command_name="$1"
  local expected="$2"
  local actual
  command -v "$command_name" >/dev/null || { echo "$command_name is required" >&2; exit 1; }
  actual="$($command_name --version 2>/dev/null | head -n 1)"
  if [[ "$actual" != *"$expected"* ]]; then
    echo "$command_name $expected is required (found: ${actual:-unknown})" >&2
    exit 1
  fi
}

npx --yes "@redocly/cli@$REDOCLY_CLI_VERSION" lint --config "$repo_root/api/openapi/redocly.yaml" "$spec"
npx --yes "@redocly/cli@$REDOCLY_CLI_VERSION" bundle --config "$repo_root/api/openapi/redocly.yaml" "$spec" --output "$repo_root/api/openapi/pocketcoder.bundle.yaml"

mkdir -p "$repo_root/server/pocketbase/internal/openapi"
go run "github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v$OAPI_CODEGEN_VERSION" \
  -config "$repo_root/api/openapi/oapi-codegen.yaml" "$spec" \
  > "$repo_root/server/pocketbase/internal/openapi/pocketcoder.gen.go"

npx --yes "@openapitools/openapi-generator-cli@$OPENAPI_GENERATOR_CLI_VERSION" generate \
  -i "$spec" \
  -g dart-dio \
  -c "$repo_root/api/openapi/dart-dio-config.yaml" \
  -o "$repo_root/client/packages/pocketcoder_api"

# OpenAPI Generator owns the package scaffold, while the repository owns its
# Dart workspace metadata. Keep this tiny normalization deterministic after
# every generation.
dart_pubspec="$repo_root/client/packages/pocketcoder_api/pubspec.yaml"
perl -0pi -e 's/name: pocketcoder_api\n/name: pocketcoder_api\nresolution: workspace\n/; s/>=2\.18\.0 <4\.0\.0/>=3.5.0 <4.0.0/' "$dart_pubspec"

# OpenAPI Generator emits trailing spaces in some model documentation and can
# leave more than one newline at EOF. Normalize every generated Dart source so
# regeneration remains compatible with git diff --check.
while IFS= read -r -d '' dart_file; do
  perl -pi -e 's/[ \t]+$//' "$dart_file"
  perl -0pi -e 's/\s*\z/\n/' "$dart_file"
done < <(find "$repo_root/client/packages/pocketcoder_api/lib" \
  "$repo_root/client/packages/pocketcoder_api/test" -type f -name '*.dart' -print0)

# OpenAPI Generator currently emits duplicate and unused imports in a small
# set of built_value API/model files. Keep the generated package analyzer-clean
# without hand-editing generated output after every contract regeneration.
for dart_file in \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/agent_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/files_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/harness_auth_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/logs_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/mcp_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/observability_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/ollama_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/push_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/release_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/schedules_api.dart"; do
  perl -0pi -e 's/import '\''package:pocketcoder_api\/src\/model\/error_response\.dart'\'';\n//g' "$dart_file"
done
# The generator's import layout changed in 7.24.0. Do not remove the block
# between duplicate json_object imports: that block contains required Dio,
# serializer, and BuiltMap imports in the current output. The file-level
# unused-import suppression below is sufficient for the remaining harmless
# generated imports.
for dart_file in \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/files_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/observability_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/schedules_api.dart"; do
  perl -0pi -e 's/import '\''package:built_value\/json_object\.dart'\'';\n//g' "$dart_file"
done
perl -0pi -e 's/import '\''package:built_collection\/built_collection\.dart'\'';\n//g; s/import '\''package:built_value\/json_object\.dart'\'';\n//g' \
  "$repo_root/client/packages/pocketcoder_api/lib/src/model/content_block.dart"

for dart_file in \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/agent_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/files_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/harness_auth_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/logs_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/mcp_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/observability_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/ollama_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/push_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/release_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/api/schedules_api.dart" \
  "$repo_root/client/packages/pocketcoder_api/lib/src/model/content_block.dart"; do
  perl -0pi -e 's#(// AUTO-GENERATED FILE, DO NOT MODIFY!\n//\n)(?!// ignore_for_file:)#$1// ignore_for_file: duplicate_import, unused_import\n#' "$dart_file"
done

(cd "$repo_root/client" && dart pub get)
(cd "$repo_root/client/packages/pocketcoder_api" && \
  dart run build_runner build --delete-conflicting-outputs)

echo "Validated PocketCoder OpenAPI contract with pinned versions:"
echo "  oapi-codegen $OAPI_CODEGEN_VERSION"
echo "  openapi-generator $OPENAPI_GENERATOR_VERSION (CLI $OPENAPI_GENERATOR_CLI_VERSION)"
echo "  redocly $REDOCLY_VERSION"
