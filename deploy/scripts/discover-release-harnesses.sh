#!/bin/sh
set -eu

manifest_file=${1:?active release manifest is required}
catalog_file=${2:?harness catalog is required}
runtime_env=${3:?runtime environment is required}

selected=$(sed -n 's/^POCKETCODER_SELECTED_HARNESSES=//p' "$runtime_env")
selected=${selected:-goose}

# The initial selection is durable configuration. Locally present images are
# a query: include every harness acquired since bootstrap so update/rollback
# preloads its matching image before the old container is removed.
jq -r '.harnesses[].id' "$catalog_file" | while IFS= read -r id; do
  include=0
  case ",$selected," in
    *",$id,"*) include=1 ;;
  esac
  if [ "$include" -eq 0 ]; then
    jq -r --arg id "$id" '.harnesses[$id].images[]?' "$manifest_file" \
      | while IFS= read -r image; do
          if docker image inspect "$image" >/dev/null 2>&1; then
            printf '%s\n' "$id"
            break
          fi
        done
  else
    printf '%s\n' "$id"
  fi
done
