#!/bin/sh
set -eu

output=${1:?output TSV path is required}
phase_file=${2:?phase file is required}
stop_file=${3:?stop file is required}
interval=${4:-5}

case "$interval" in
  '' | *[!0-9]*) echo "interval must be a positive integer" >&2; exit 1 ;;
esac
[ "$interval" -gt 0 ] || { echo "interval must be positive" >&2; exit 1; }

install -d -m 0755 "$(dirname -- "$output")"
printf 'timestamp\tphase\tkind\tname\tbytes\n' > "$output"

process_bytes() {
  process_name=$1
  total_kib=0
  for process_dir in /proc/[0-9]*; do
    [ -d "$process_dir" ] || continue
    executable=$(readlink "$process_dir/exe" 2>/dev/null || true)
    executable=${executable##*/}
    command=$(cat "$process_dir/comm" 2>/dev/null || true)
    if [ "$executable" != "$process_name" ] &&
       [ "$command" != "$process_name" ]; then
      continue
    fi
    status=$process_dir/status
    [ -r "$status" ] || continue
    rss_kib=$(awk '$1 == "VmRSS:" {print $2}' "$status")
    total_kib=$((total_kib + ${rss_kib:-0}))
  done
  printf '%s\n' "$((total_kib * 1024))"
}

emit() {
  kind=$1
  name=$2
  bytes=$3
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$timestamp" "$phase" "$kind" "$name" "$bytes" >> "$output"
}

while [ ! -e "$stop_file" ]; do
  timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  phase=$(cat "$phase_file" 2>/dev/null || printf 'unknown')
  total_kib=$(awk '$1 == "MemTotal:" {print $2}' /proc/meminfo)
  available_kib=$(awk '$1 == "MemAvailable:" {print $2}' /proc/meminfo)
  emit host total-memory "$((total_kib * 1024))"
  emit host available-memory "$((available_kib * 1024))"
  emit host used-memory "$(((total_kib - available_kib) * 1024))"

  emit process caddy "$(process_bytes caddy)"
  emit process dockerd "$(process_bytes dockerd)"
  emit process containerd "$(process_bytes containerd)"
  emit process containerd-shim "$(process_bytes containerd-shim)"
  emit process pocketcoder-release "$(process_bytes pocketcoder-release)"

  for id in $(docker ps -q 2>/dev/null || true); do
    name=$(docker inspect --format '{{.Name}}' "$id" 2>/dev/null | sed 's|^/||')
    [ -n "$name" ] || continue
    stats=$(curl -sS --max-time 5 --unix-socket /var/run/docker.sock \
      "http://localhost/containers/$id/stats?stream=false" 2>/dev/null || true)
    [ -n "$stats" ] || continue
    working_set=$(printf '%s' "$stats" | jq -r '
      (.memory_stats.usage // 0) -
      (.memory_stats.stats.inactive_file // 0) |
      if . < 0 then 0 else . end
    ' 2>/dev/null || true)
    case "$working_set" in '' | *[!0-9]*) continue ;; esac
    emit container "$name" "$working_set"
  done
  sleep "$interval"
done
