#!/bin/sh
set -eu

manifest_candidate=${1:?downloaded release manifest is required}
immutable_url=${2:?immutable manifest URL is required}
runtime_env=${3:?runtime environment file is required}
release_state=${4:?release state directory is required}
artifact_dir=${5:?artifact directory is required}
run_id=${6:?provisioning run ID is required}
status_file=${7:?provisioning status file is required}
shift 7

if [ "$#" -eq 0 ]; then
  echo "at least one harness must be selected" >&2
  exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source "$script_dir/status-merge.sh"
release_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
catalog="$release_dir/deploy/release/harnesses.json"
compose_file="$release_dir/docker-compose.prebuilt.yml"
current_link=${POCKETCODER_CURRENT_LINK:-/opt/pocketcoder/current}
release=$(jq -r '.release // empty' "$manifest_candidate")
current_phase=loading_images
failure_reported=0

write_status() {
  phase=$1
  detail=${2:-}
  error=${3:-}
  pc_status_update "$status_file" "$run_id" "$release" "$phase" "$detail" "$error"
}

on_exit() {
  rc=$?
  if [ "$rc" -ne 0 ] && [ "$failure_reported" -ne 1 ]; then
    write_status "$current_phase" failed release_activation_failed
  fi
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 1' HUP INT TERM

# POCO:BEGIN bootstrap-activation-prepare
test "$(jq -r '.release // empty' "$release_dir/release.json")" = "$release"
"$script_dir/validate-release-contract.sh" "$manifest_candidate" "$catalog"
"$script_dir/prepare-runtime-env.sh" "$runtime_env" "$release"
install -d -m 0755 "$release_state/manifests"
install -d -m 0700 "$artifact_dir"

manifest_cache="$release_state/manifests/$release.json"
manifest_tmp="$manifest_cache.tmp.$$"
cp "$manifest_candidate" "$manifest_tmp"
chmod 0644 "$manifest_tmp"
mv -f "$manifest_tmp" "$manifest_cache"
# POCO:END bootstrap-activation-prepare

# POCO:BEGIN bootstrap-verified-images
# Load only the core and explicitly selected harness archives. Each archive is
# size-checked and checksum-verified before Docker is allowed to read it.
write_status loading_images resolving:selected-harnesses
if ! "$script_dir/install-release-images.sh" \
  "$manifest_cache" "$catalog" "$artifact_dir" "$run_id" "$status_file" "$@"; then
  failure_reported=1
  exit 1
fi
# POCO:END bootstrap-verified-images

# POCO:BEGIN bootstrap-compose-start
# Switch the stable path only after all required images are present, then
# recreate managed containers without building or touching persistent volumes.
current_phase=compose_up
current_link_tmp="$current_link.tmp.$$"
if [ -e "$current_link" ] && [ ! -L "$current_link" ]; then
  echo "current release path is not a symbolic link: $current_link" >&2
  exit 1
fi
ln -s "$release_dir" "$current_link_tmp"
# GNU mv needs -T and BSD mv needs -h to replace a symlink-to-directory
# itself instead of moving the temporary link *inside* its target directory.
# Both forms still perform a single atomic rename on their respective hosts.
if mv -Tf "$current_link_tmp" "$current_link" 2>/dev/null; then
  :
else
  mv -fh "$current_link_tmp" "$current_link"
fi

write_status compose_up
if docker compose version >/dev/null 2>&1; then
  docker compose --project-name pocketcoder --env-file "$runtime_env" \
    -f "$compose_file" up -d --no-build --remove-orphans
else
  docker-compose --project-name pocketcoder --env-file "$runtime_env" \
    -f "$compose_file" up -d --no-build --remove-orphans
fi

# A candidate is not active merely because Docker accepted `compose up`.
# Keep the durable release pointer on the previous version until the matching
# PocketBase process has completed startup and answers its local health route.
current_phase=finishing_up
write_status finishing_up waiting:core-health
if [ "${POCKETCODER_SKIP_HEALTHCHECK:-0}" != 1 ]; then
  health_url=${POCKETCODER_HEALTH_URL:-http://127.0.0.1:8090/api/health}
  health_attempts=${POCKETCODER_HEALTH_ATTEMPTS:-90}
  health_interval=${POCKETCODER_HEALTH_INTERVAL_SECONDS:-2}
  healthy=0
  attempt=1
  while [ "$attempt" -le "$health_attempts" ]; do
    if curl -fsS --max-time 5 "$health_url" >/dev/null 2>&1; then
      healthy=1
      break
    fi
    sleep "$health_interval"
    attempt=$((attempt + 1))
  done
  if [ "$healthy" -ne 1 ]; then
    echo "PocketCoder core did not become healthy" >&2
    exit 1
  fi
fi

if [ "${POCKETCODER_ENABLE_OLLAMA:-0}" = 1 ]; then
  write_status finishing_up starting:ollama
  if docker compose version >/dev/null 2>&1; then
    docker compose --project-name pocketcoder --env-file "$runtime_env" \
      -f "$compose_file" --profile local-models up -d --no-build ollama
  else
    docker-compose --project-name pocketcoder --env-file "$runtime_env" \
      -f "$compose_file" --profile local-models up -d --no-build ollama
  fi
  if [ "${POCKETCODER_SKIP_HEALTHCHECK:-0}" != 1 ]; then
    ollama_healthy=0
    attempt=1
    while [ "$attempt" -le "$health_attempts" ]; do
      if [ "$(docker inspect --format '{{.State.Health.Status}}' pocketcoder-ollama 2>/dev/null || true)" = healthy ]; then
        ollama_healthy=1
        break
      fi
      sleep "$health_interval"
      attempt=$((attempt + 1))
    done
    if [ "$ollama_healthy" -ne 1 ]; then
      echo "Ollama did not become healthy" >&2
      exit 1
    fi
  fi
fi

pointer_tmp="$release_state/current.json.tmp.$$"
jq -n --arg release "$release" --arg manifestUrl "$immutable_url" \
  --arg activatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schemaVersion:1,manifestSchemaVersion:2,release:$release,
    manifestUrl:$manifestUrl,activatedAt:$activatedAt}' > "$pointer_tmp"
chmod 0644 "$pointer_tmp"
mv -f "$pointer_tmp" "$release_state/current.json"
rm -f "$manifest_candidate"
write_status bootstrap_complete
# POCO:END bootstrap-compose-start

if [ -n "${POCKETCODER_INITIALIZED_MARKER:-}" ]; then
  date -u +%Y-%m-%dT%H:%M:%SZ > "$POCKETCODER_INITIALIZED_MARKER"
fi

trap - EXIT HUP INT TERM
