#!/usr/bin/env python3
"""
network_matrix_test.py
Runs on the HOST. 
- Reads docker-compose.yml to determine the INTENDED network topology.

NOTE on opencode container:
  The opencode container sets SHELL=/usr/local/bin/pocketcoder-shell which intercepts
  ALL shell command execution (including bash /dev/tcp probes) and routes them through
  the sandbox's Rust proxy at http://sandbox:3001/exec. This means any probe run
  FROM opencode is actually executing INSIDE the sandbox container.
  
  Therefore: opencode is EXCLUDED from source tests. We test connectivity TO opencode
  from all other containers instead.
- Inspects running containers to get ACTUAL network memberships and IPs.
- Tests TCP connectivity from each container to each service endpoint.
- Compares actual vs expected, flags violations.
- Uses only /dev/tcp (bash built-in) or nc as probes inside containers
  (no curl/python3 required inside containers).
"""

import subprocess, json, sys, os, yaml
from itertools import product
from pathlib import Path

# ── ANSI Colours ───────────────────────────────────────────────────────────────
R="\033[0;31m"; G="\033[0;32m"; Y="\033[1;33m"
C="\033[0;36m"; B="\033[1m"; RST="\033[0m"

COMPOSE_FILE = Path(__file__).parent.parent / "docker-compose.yml"
PROJECT = "pocketcoder"  # docker compose project prefix

# ── Service → port map (well-known ports to test) ─────────────────────────────
SERVICE_PORTS = {
    "pocketbase":               [("pocketbase",              8090)],
    "opencode":                 [("opencode",                3000)],
    "sandbox":                  [("sandbox",                 3001),
                                 ("sandbox",                 9888),
                                 ("sandbox",                 9889)],
    "mcp-gateway":              [("mcp-gateway",             8811)],
    "docker-socket-proxy-write":[("docker-socket-proxy-write", 2375)],
    "n8n":                      [("n8n",                     5678)],
}

# Containers whose outbound probes CANNOT be trusted because shell is intercepted.
# We skip these as sources but still test connectivity TO them.
UNTRUSTED_SOURCES = {"pocketcoder-opencode"}

# Explicit override for containers whose name doesn't match the compose service name
CONTAINER_TO_SERVICE_OVERRIDE = {
    "pocketcoder-n8n-demo":            "n8n",
    "pocketcoder-docker-proxy-write":   "docker-socket-proxy-write",
}

# ── 1. Parse docker-compose.yml for intended network membership ────────────────
def parse_compose(path):
    with open(path) as f:
        compose = yaml.safe_load(f)

    services = compose.get("services", {})
    svc_networks = {}  # service_name -> set of network names
    for svc_name, svc in services.items():
        nets = svc.get("networks", {})
        if isinstance(nets, list):
            svc_networks[svc_name] = set(nets)
        elif isinstance(nets, dict):
            svc_networks[svc_name] = set(nets.keys())
        else:
            svc_networks[svc_name] = set()
    return svc_networks

# ── 2. Derive EXPECTED reachability from shared networks ──────────────────────
def expected_pairs(svc_networks):
    """Two services can communicate iff they share >= 1 network."""
    pairs = set()
    svcs = list(svc_networks.keys())
    for a, b in product(svcs, svcs):
        if a != b and svc_networks[a] & svc_networks[b]:
            pairs.add((a, b))
    return pairs

# ── 3. Get actual running containers and their real network memberships ─────────
def get_containers():
    out = subprocess.check_output(
        ["docker", "ps", "--format", "{{.Names}}"], text=True
    ).strip().split("\n")
    return [c for c in out if c.startswith(f"{PROJECT}-")]

def get_container_networks(container):
    data = subprocess.check_output(
        ["docker", "inspect", container], text=True
    )
    info = json.loads(data)[0]
    nets = info["NetworkSettings"]["Networks"]
    # Strip project prefix from network names
    result = {}
    for full_name, cfg in nets.items():
        short = full_name.replace(f"{PROJECT}_{PROJECT}-", "").replace(f"{PROJECT}_", "")
        result[short] = cfg["IPAddress"]
    return result

def container_to_service(container_name):
    """Map container name to compose service name."""
    if container_name in CONTAINER_TO_SERVICE_OVERRIDE:
        return CONTAINER_TO_SERVICE_OVERRIDE[container_name]
    return container_name[len(f"{PROJECT}-"):]

# ── 4. TCP probe script (runs inside any container via sh) ─────────────────────
def make_probe(host, port):
    return f"""
h="{host}"; p={port}; r=1
if command -v bash >/dev/null 2>&1; then
  bash -c "( exec 3<>/dev/tcp/$h/$p ) 2>/dev/null" && r=0
fi
if [ $r -ne 0 ] && command -v nc >/dev/null 2>&1; then
  nc -z -w3 "$h" "$p" 2>/dev/null && r=0
fi
echo $r
"""

def probe(container, host, port, timeout=6):
    script = make_probe(host, port)
    try:
        out = subprocess.check_output(
            ["docker", "exec", container, "sh", "-c", script],
            stderr=subprocess.DEVNULL, timeout=timeout, text=True
        ).strip()
        return out.split()[-1] == "0"  # last line is the result digit
    except Exception:
        return False

# ──────────────────────────────────────────────────────────────────────────────
def main():
    # Check docker-compose.yml exists
    if not COMPOSE_FILE.exists():
        print(f"{R}ERROR: {COMPOSE_FILE} not found. Run from repo root.{RST}")
        sys.exit(1)

    # Check yaml available
    try:
        import yaml
    except ImportError:
        print(f"{R}ERROR: PyYAML not available. Run: pip install pyyaml{RST}")
        sys.exit(1)

    print(f"\n{B}{C}╔══════════════════════════════════════════════════════════════╗{RST}")
    print(f"{B}{C}║       PocketCoder Network Connectivity Matrix Test v2        ║{RST}")
    print(f"{B}{C}╚══════════════════════════════════════════════════════════════╝{RST}\n")

    # Parse intended topology
    print(f"{B}[1/4] Parsing docker-compose.yml for intended network topology...{RST}")
    svc_networks = parse_compose(COMPOSE_FILE)
    expected = expected_pairs(svc_networks)

    print(f"\n{B}Intended service networks:{RST}")
    for svc, nets in sorted(svc_networks.items()):
        print(f"  {C}{svc:<35}{RST} {', '.join(sorted(nets)) or '(none)'}")

    print(f"\n{B}Expected communication pairs (share >=1 network):{RST}")
    for a, b in sorted(expected):
        shared = svc_networks[a] & svc_networks[b]
        print(f"  {G}{a} ↔ {b}{RST}  via [{', '.join(sorted(shared))}]")

    # Get running containers
    print(f"\n{B}[2/4] Discovering running containers...{RST}")
    containers = get_containers()
    container_networks = {}
    print(f"\n{B}Actual container IPs (live):{RST}")
    for c in sorted(containers):
        nets = get_container_networks(c)
        container_networks[c] = nets
        svc = container_to_service(c)
        print(f"  {C}{c:<40}{RST} networks: {nets}")

    # Build test targets
    print(f"\n{B}[3/4] Running TCP connectivity matrix...{RST}")
    print(f"      (Probe: bash /dev/tcp or nc — no curl required)")
    print(f"      {Y}NOTE: opencode excluded as source (pocketcoder-shell proxy intercepts all sh calls){RST}\n")

    # Column headers
    all_targets = []
    for svc, endpoints in SERVICE_PORTS.items():
        for (host, port) in endpoints:
            all_targets.append((svc, host, port))

    col_w = 20
    row_w = 38
    print(f"{B}{'SOURCE':<{row_w}}{RST}", end="")
    for (svc, host, port) in all_targets:
        label = f"{host}:{port}"
        print(f" {B}{label:<{col_w}}{RST}", end="")
    print()
    print("─" * row_w + (" " + "─"*col_w) * len(all_targets))

    results = []  # (from_container, from_svc, to_svc, host, port, open, expected_open)

    for container in sorted(containers):
        if container in UNTRUSTED_SOURCES:
            print(f"{Y}{container:<{row_w}} [SKIPPED — shell proxy intercepts probes]{RST}")
            continue
        from_svc = container_to_service(container)
        print(f"{B}{container:<{row_w}}{RST}", end="", flush=True)

        for (to_svc, host, port) in all_targets:
            # Determine if this should be open per intended topology
            should_be_open = (from_svc, to_svc) in expected or (to_svc, from_svc) in expected
            # Self-connection always skip (or mark as expected)
            if from_svc == to_svc:
                should_be_open = True

            is_open = probe(container, host, port)
            results.append((container, from_svc, to_svc, host, port, is_open, should_be_open))

            label = f"{'OPEN' if is_open else 'blocked'}"
            if is_open and should_be_open:
                cell = f"{G}{label + ' ✓':<{col_w}}{RST}"
            elif is_open and not should_be_open:
                cell = f"{R}{'OPEN ⚠ LEAK':<{col_w}}{RST}"
            elif not is_open and should_be_open:
                cell = f"{Y}{'BLOCKED ⚠':<{col_w}}{RST}"
            else:
                cell = f"{C}{'blocked ✓':<{col_w}}{RST}"

            print(f" {cell}", end="", flush=True)
        print()

    # ── Summary ────────────────────────────────────────────────────────────────
    print(f"\n{B}{C}{'═'*65}{RST}")
    print(f"{B}{C}  SECURITY VIOLATIONS SUMMARY{RST}")
    print(f"{B}{C}{'═'*65}{RST}\n")

    leaks    = [(c,fs,ts,h,p) for c,fs,ts,h,p,op,ex in results if op  and not ex and fs!=ts]
    broken   = [(c,fs,ts,h,p) for c,fs,ts,h,p,op,ex in results if not op and ex]
    ok_open  = [(c,fs,ts,h,p) for c,fs,ts,h,p,op,ex in results if op  and ex]
    ok_block = [(c,fs,ts,h,p) for c,fs,ts,h,p,op,ex in results if not op and not ex]

    print(f"  {G}✓ Expected open  :{RST} {len(ok_open):>3} connections")
    print(f"  {C}✓ Expected closed:{RST} {len(ok_block):>3} connections")
    print(f"  {Y}⚠ Broken isolat. :{RST} {len(broken):>3} (should be open, are blocked)")
    print(f"  {R}⚠ SECURITY LEAKS :{RST} {len(leaks):>3} (should be isolated, ARE OPEN)\n")

    if leaks:
        print(f"{R}{B}  ┌─ SECURITY LEAKS (unexpected open connections) ──────────────┐{RST}")
        for (c, fs, ts, h, p) in sorted(leaks):
            shared = svc_networks.get(fs,set()) & svc_networks.get(ts,set())
            print(f"{R}  │  {fs}  →  {ts}:{p}  (no shared network!){RST}")

        print(f"{R}{B}  └──────────────────────────────────────────────────────────────┘{RST}")
        print(f"""
{R}{B}  ROOT CAUSE:{RST}
  Docker assigns all bridge networks in the same IP space (172.x.0.0/16).
  All bridges are on the same Linux kernel routing table. Without explicit
  iptables FORWARD DROP rules between subnets, packets cross bridges freely.
  Docker Desktop for Mac does NOT enforce the DOCKER-ISOLATION iptables chains
  the same way native Linux does.

{B}  HOW TO FIX:{RST}

  Option A — Host iptables rules (Linux/native Docker only):
    Add FORWARD DROP rules between each pair of bridge subnets that should
    not communicate. Automate with a startup script. NOT reliable on Docker Desktop.

  Option B — Application-layer authentication (recommended for Docker Desktop):
    Add bearer-token authentication to every internal endpoint:
      • sandbox Rust proxy   (port 3001) — already has OPENCODE_SESSION_ID concept
      • sandbox CAO MCP/API  (9888/9889) — add MCP_GATEWAY_AUTH_TOKEN support
      • opencode serve        (3000)      — already has auth built in
    Even if a container can TCP-connect, it cannot do anything useful without a token.

  Option C — Eliminate unnecessary cross-network exposure:
    • Remove config bleed (sandbox opencode.json read by opencode container)
    • Use a dedicated n8n service account user (limit what n8n can see)
    • Do NOT mount /var/run/docker.sock directly in mcp-gateway (use proxy when supported)

  Option D — Custom subnets (prevents routing at kernel level):
    Assign non-overlapping subnets that the kernel won't auto-route between:

    networks:
      pocketcoder-relay:
        driver: bridge
        ipam:
          config: [{{subnet: "10.10.0.0/24"}}]
      pocketcoder-control:
        driver: bridge
        ipam:
          config: [{{subnet: "10.10.1.0/24"}}]
      pocketcoder-tools:
        driver: bridge
        ipam:
          config: [{{subnet: "10.10.2.0/24"}}]
      pocketcoder-docker:
        driver: bridge
        ipam:
          config: [{{subnet: "10.10.3.0/24"}}]

    This alone may NOT stop routing on Docker Desktop (kernel still routes /24 between bridges),
    but combined with Option B (auth tokens) gives defense-in-depth.

  {B}RECOMMENDED FOR MVP:{RST}
    Implement Option B (auth tokens on internal ports) + Option C (config/volume cleanup).
    These work on Docker Desktop, are portable, and follow zero-trust principles.
    Network-level isolation (Options A/D) should be added for production hardening.
""")
    else:
        print(f"  {G}{B}  ✅ No security leaks detected!{RST}")

    if broken:
        print(f"\n{Y}{B}  ⚠ Broken expected paths (may cause runtime failures):{RST}")
        for (c, fs, ts, h, p) in broken:
            print(f"  {Y}  {fs} cannot reach {ts}:{p} (expected to be open){RST}")

    print(f"\n{B}Legend:{RST}")
    print(f"  {G}OPEN ✓{RST}        expected and open  (correct)")
    print(f"  {C}blocked ✓{RST}     expected and closed (correct)")
    print(f"  {R}OPEN ⚠ LEAK{RST}   open but should be isolated ← {R}{B}security violation{RST}")
    print(f"  {Y}BLOCKED ⚠{RST}    closed but should be open   ← config/service issue\n")

if __name__ == "__main__":
    main()
