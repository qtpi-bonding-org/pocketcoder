#!/usr/bin/env bash
# PocketCoder standard Linux host hardening.
#
# This intentionally targets Ubuntu/Debian VPS hosts only. It is explicit and
# opt-in because changing a host firewall or SSH policy can strand a machine.

set -euo pipefail

if [[ "${1:-}" != "--apply" ]]; then
  echo "Usage: sudo $0 --apply" >&2
  echo "This changes SSH, UFW, Fail2ban, unattended-upgrades, and Docker firewall rules." >&2
  exit 2
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This hardening script supports Linux VPS hosts only." >&2
  exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root, for example: sudo $0 --apply" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify the Linux distribution." >&2
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *)
    echo "Unsupported distribution: ${ID:-unknown}. This script supports Ubuntu/Debian." >&2
    exit 1
    ;;
esac

if ! command -v docker >/dev/null 2>&1 || ! systemctl is-active --quiet docker; then
  echo "Rootful Docker must be installed and running before host hardening." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ufw fail2ban unattended-upgrades iptables

mkdir -p /etc/ssh/sshd_config.d /etc/fail2ban/jail.d

# Keep root key recovery available, but remove password and forwarding paths.
cat > /etc/ssh/sshd_config.d/99-pocketcoder-hardening.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
EOF

SSHD_BIN="$(command -v sshd || true)"
if [[ -z "${SSHD_BIN}" ]]; then
  echo "sshd is not installed; refusing to continue." >&2
  exit 1
fi
"${SSHD_BIN}" -t

SSH_PORTS="$("${SSHD_BIN}" -T | awk '$1 == "port" { print $2 }' | sort -nu)"
if [[ -z "${SSH_PORTS}" ]]; then
  SSH_PORTS=22
fi

# Configure the host firewall before enabling it. Docker's published ports
# traverse FORWARD/DOCKER rather than only the host INPUT chain, so the
# companion DOCKER-USER rules below enforce the same public allowlist there.
ufw default deny incoming
ufw default allow outgoing
while IFS= read -r port; do
  [[ -n "${port}" ]] && ufw allow "${port}/tcp" comment "PocketCoder SSH"
done <<< "${SSH_PORTS}"
ufw allow 80/tcp comment "PocketCoder HTTPS redirect"
ufw allow 443/tcp comment "PocketCoder HTTPS"
ufw --force enable

cat > /etc/fail2ban/jail.d/pocketcoder-sshd.local <<'EOF'
[sshd]
enabled = true
backend = systemd
mode = aggressive
maxretry = 5
bantime = 1h
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

install -d -m 0755 /usr/local/sbin
cat > /usr/local/sbin/pocketcoder-docker-firewall <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

apply_ipv4_rules() {
  local cmd="iptables"
  command -v "${cmd}" >/dev/null 2>&1 || return 0
  "${cmd}" -N POCKETCODER-DOCKER 2>/dev/null || true
  "${cmd}" -F POCKETCODER-DOCKER
  "${cmd}" -A POCKETCODER-DOCKER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -d 169.254.169.254 -j DROP
  "${cmd}" -A POCKETCODER-DOCKER -s 127.0.0.0/8 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -s 10.0.0.0/8 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -s 172.16.0.0/12 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -s 192.168.0.0/16 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -s 100.64.0.0/10 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -p tcp -m multiport --dports 80,443 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -m conntrack --ctstate NEW -j DROP
  "${cmd}" -A POCKETCODER-DOCKER -j RETURN
  "${cmd}" -C DOCKER-USER -j POCKETCODER-DOCKER 2>/dev/null || \
    "${cmd}" -I DOCKER-USER 1 -j POCKETCODER-DOCKER
}

apply_ipv6_rules() {
  local cmd="ip6tables"
  command -v "${cmd}" >/dev/null 2>&1 || return 0
  "${cmd}" -N POCKETCODER-DOCKER 2>/dev/null || true
  "${cmd}" -F POCKETCODER-DOCKER
  "${cmd}" -A POCKETCODER-DOCKER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -s ::1/128 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -s fc00::/7 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -s fe80::/10 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -p tcp -m multiport --dports 80,443 -j RETURN
  "${cmd}" -A POCKETCODER-DOCKER -m conntrack --ctstate NEW -j DROP
  "${cmd}" -A POCKETCODER-DOCKER -j RETURN
  "${cmd}" -C DOCKER-USER -j POCKETCODER-DOCKER 2>/dev/null || \
    "${cmd}" -I DOCKER-USER 1 -j POCKETCODER-DOCKER
}

apply_ipv4_rules
apply_ipv6_rules
EOF
chmod 0755 /usr/local/sbin/pocketcoder-docker-firewall

cat > /etc/systemd/system/pocketcoder-docker-firewall.service <<'EOF'
[Unit]
Description=PocketCoder Docker forwarding firewall
After=docker.service ufw.service
Wants=docker.service ufw.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/pocketcoder-docker-firewall
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now fail2ban apt-daily.timer apt-daily-upgrade.timer pocketcoder-docker-firewall
systemctl reload ssh || systemctl reload sshd

echo "PocketCoder host hardening applied. Verify a second SSH session before closing this one."
echo "Expected public ports: SSH (${SSH_PORTS//$'\n'/, }), 80, and 443."
