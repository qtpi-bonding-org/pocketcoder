#!/bin/bash
# network_matrix_test.sh
# Runs on the HOST via docker exec.
# Tests TCP connectivity from every container to every service endpoint.
# Uses /dev/tcp bash built-in (no curl/python3 needed). Falls back to nc.

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Target matrix ──────────────────────────────────────────────────────────────
# Format:  "label:host:port"
TARGETS=(
  "pocketbase:8090:pocketbase:8090"
  "opencode:3000:opencode:3000"
  "sandbox-proxy:3001:sandbox:3001"
  "sandbox-cao:9889:sandbox:9889"
  "sandbox-mcp:9888:sandbox:9888"
  "mcp-gateway:8811:mcp-gateway:8811"
  "docker-proxy:2375:docker-socket-proxy-write:2375"
  "n8n:5678:n8n:5678"
)

# Format:  "container-name"
CONTAINERS=(
  "pocketcoder-pocketbase"
  "pocketcoder-opencode"
  "pocketcoder-sandbox"
  "pocketcoder-mcp-gateway"
  "pocketcoder-docker-proxy-write"
  "pocketcoder-n8n-demo"
)

# ── Probe function (runs inside container via docker exec) ─────────────────────
# Uses bash /dev/tcp if available, then nc, then always fails gracefully.
probe_script() {
  local host="$1"
  local port="$2"
  cat <<EOF
host="$host"
port="$port"
result=99

# Method 1: bash /dev/tcp
if [ -n "\$(command -v bash 2>/dev/null)" ]; then
  bash -c "exec 3<>/dev/tcp/\$host/\$port 2>/dev/null && exec 3>&-" 2>/dev/null && result=0 || true
fi

# Method 2: nc (if bash /dev/tcp failed)
if [ "\$result" -ne 0 ] && command -v nc >/dev/null 2>&1; then
  nc -z -w 3 "\$host" "\$port" 2>/dev/null && result=0 || result=1
fi

# Method 3: GNU Timeout + /bin/sh read (last resort)
if [ "\$result" -ne 0 ] && command -v timeout >/dev/null 2>&1; then
  timeout 3 sh -c "cat < /dev/null > /dev/tcp/\$host/\$port" 2>/dev/null && result=0 || true
fi

echo "\$result"
EOF
}

# ── Network topology summary ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║   PocketCoder Network Connectivity Matrix Test   ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${BOLD}Network topology (from docker-compose):${RESET}"
echo "  pocketcoder-relay:     pocketbase, opencode"
echo "  pocketcoder-control:   opencode, sandbox"
echo "  pocketcoder-tools:     sandbox, mcp-gateway, n8n"
echo "  pocketcoder-docker:    pocketbase, mcp-gateway, docker-proxy-write"
echo "  pocketcoder-dashboard: pocketbase, sqlpage"
echo ""
echo -e "${BOLD}IP Addresses:${RESET}"
for net in pocketcoder_pocketcoder-relay pocketcoder_pocketcoder-control pocketcoder_pocketcoder-tools pocketcoder_pocketcoder-docker; do
  short="${net#pocketcoder_pocketcoder-}"
  echo -e "  ${CYAN}[$short]${RESET}"
  docker network inspect "$net" 2>/dev/null | \
    python3 -c "
import sys,json
data=json.load(sys.stdin)[0]
for cid,c in data['Containers'].items():
    print(f\"    {c['Name']}: {c['IPv4Address']}\")
" 2>/dev/null || echo "    (inspect failed)"
done
echo ""

# ── Matrix header ───────────────────────────────────────────────────────────────
# Build column labels
COL_LABELS=()
COL_HOSTS=()
COL_PORTS=()
for t in "${TARGETS[@]}"; do
  IFS=: read -r label _ignored host port <<< "$t"
  COL_LABELS+=("$label")
  COL_HOSTS+=("$host")
  COL_PORTS+=("$port")
done

# Print header row
printf "${BOLD}%-30s${RESET}" "FROM \\ TO"
for label in "${COL_LABELS[@]}"; do
  printf " ${BOLD}%-15s${RESET}" "$label"
done
echo ""
printf "%s" "$(printf '─%.0s' {1..30})"
for _ in "${COL_LABELS[@]}"; do
  printf "%s" " $(printf '─%.0s' {1..15})"
done
echo ""

OPEN_COUNT=0
BLOCKED_COUNT=0
UNEXPECTED_OPEN=""
UNEXPECTED_BLOCKED=""

# Expected open connections (from:to label, "." separated):
EXPECTED_OPEN=(
  # opencode is on relay+control → can reach pocketbase (relay) and sandbox (control)
  "pocketcoder-opencode:pocketbase:8090"
  "pocketcoder-opencode:sandbox-proxy:3001"
  "pocketcoder-opencode:sandbox-cao:9889"
  "pocketcoder-opencode:sandbox-mcp:9888"
  # sandbox is on control+tools → can reach opencode (control), mcp-gateway (tools), n8n (tools)
  "pocketcoder-sandbox:opencode:3000"
  "pocketcoder-sandbox:mcp-gateway:8811"
  "pocketcoder-sandbox:n8n:5678"
  # mcp-gateway is on tools+docker → can reach n8n (tools), docker-proxy (docker), pocketbase (docker)
  "pocketcoder-mcp-gateway:pocketbase:8090"
  "pocketcoder-mcp-gateway:docker-proxy:2375"
  "pocketcoder-mcp-gateway:n8n:5678"
  # pocketbase is on relay+docker+dashboard → can reach opencode (relay), docker-proxy (docker)
  "pocketcoder-pocketbase:opencode:3000"
  "pocketcoder-pocketbase:docker-proxy:2375"
)

# ── Main probe loop ─────────────────────────────────────────────────────────────
for container in "${CONTAINERS[@]}"; do
  # Check if container is running
  if ! docker inspect "$container" --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
    printf "%-30s" "$container"
    echo -e " ${YELLOW}(not running)${RESET}"
    continue
  fi

  short_name="$container"
  printf "${BOLD}%-30s${RESET}" "$short_name"

  for i in "${!COL_LABELS[@]}"; do
    label="${COL_LABELS[$i]}"
    host="${COL_HOSTS[$i]}"
    port="${COL_PORTS[$i]}"

    # Skip self-to-self port
    container_short="${container#pocketcoder-}"
    target_short="${host}"

    # Run the probe inside the container
    script="$(probe_script "$host" "$port")"
    result=$(docker exec "$container" sh -c "$script" 2>/dev/null || echo "99")
    result=$(echo "$result" | tr -d '[:space:]')

    # Build expectation key
    key="${container}:${label}"

    if [ "$result" = "0" ]; then
      OPEN_COUNT=$((OPEN_COUNT + 1))
      is_expected=false
      for exp in "${EXPECTED_OPEN[@]}"; do
        if [ "$exp" = "$key" ]; then is_expected=true; break; fi
      done
      if $is_expected; then
        printf " ${GREEN}%-15s${RESET}" "OPEN ✓"
      else
        printf " ${RED}%-15s${RESET}" "OPEN ⚠ UNEXP"
        UNEXPECTED_OPEN="${UNEXPECTED_OPEN}\n  ${container} → ${label}:${port}"
      fi
    else
      BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
      is_expected_blocked=true
      for exp in "${EXPECTED_OPEN[@]}"; do
        if [ "$exp" = "$key" ]; then is_expected_blocked=false; break; fi
      done
      if $is_expected_blocked; then
        printf " ${CYAN}%-15s${RESET}" "blocked ✓"
      else
        printf " ${YELLOW}%-15s${RESET}" "BLOCKED ⚠"
        UNEXPECTED_BLOCKED="${UNEXPECTED_BLOCKED}\n  ${container} → ${label}:${port}"
      fi
    fi
  done
  echo ""
done

# ── Summary ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}═══════════════════ SUMMARY ═══════════════════${RESET}"
echo -e "  Open connections:    $OPEN_COUNT"
echo -e "  Blocked connections: $BLOCKED_COUNT"

if [ -n "$UNEXPECTED_OPEN" ]; then
  echo ""
  echo -e "${RED}${BOLD}⚠ UNEXPECTED OPEN (security concern):${RESET}"
  echo -e "$UNEXPECTED_OPEN"
fi

if [ -n "$UNEXPECTED_BLOCKED" ]; then
  echo ""
  echo -e "${YELLOW}${BOLD}⚠ UNEXPECTEDLY BLOCKED (config concern):${RESET}"
  echo -e "$UNEXPECTED_BLOCKED"
fi

echo ""
echo -e "${BOLD}Legend:${RESET}"
echo -e "  ${GREEN}OPEN ✓${RESET}       = reachable and expected"
echo -e "  ${CYAN}blocked ✓${RESET}    = unreachable and expected (good isolation)"
echo -e "  ${RED}OPEN ⚠ UNEXP${RESET} = reachable but SHOULD be isolated  ← security flaw"
echo -e "  ${YELLOW}BLOCKED ⚠${RESET}   = unreachable but should be reachable ← config issue"
echo ""
