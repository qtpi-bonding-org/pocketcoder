# Standard Linux self-hosting (manual, unsupported)

**This path is not provisioned or deployed by the PocketCoder app.** The
app's own onboarding (`NixosInitializationFacade`) supports NixOS only.

These two scripts are a DIY reference for anyone who wants to run PocketCoder
on a plain Ubuntu/Debian VPS by hand instead. There is no app integration,
no automated provisioning, and no support commitment: you run these scripts
yourself, on a box you already have root on, and you're responsible for
keeping it running.

## What these scripts do

- **`harden-host.sh`** — locks down a fresh Ubuntu/Debian host before you
  expose it: SSH key-only login (`PermitRootLogin prohibit-password`,
  `PasswordAuthentication no`), UFW allowing only SSH + 80/443, Fail2ban on
  sshd, unattended security upgrades, and a `DOCKER-USER` iptables/ip6tables
  chain that blocks the cloud metadata endpoint (`169.254.169.254`) and any
  inbound traffic to Docker-published ports other than 80/443 (Docker
  otherwise bypasses the host firewall for published ports).
- **`setup-caddy.sh`** — installs Caddy from the native apt repo, detects
  the box's public IPv4 address, and configures it as a reverse proxy in
  front of PocketBase on `127.0.0.1:8090`, using an automatically derived
  `<ip-with-dashes>.sslip.io` hostname with an ACME/ZeroSSL certificate —
  the same DNS-free approach the NixOS path uses. It also installs a
  systemd timer that republishes Caddy's certificate state to
  `/var/lib/pocketcoder/public/status.json` every 30s.

## Prerequisites

- A fresh Ubuntu or Debian VPS with root SSH access. Both scripts read
  `/etc/os-release` and refuse to run on anything else.
- Rootful Docker already installed and running (`harden-host.sh` checks for
  this and exits if it's missing — install Docker first).
- The PocketCoder application stack (PocketBase etc.) deployed separately,
  listening on loopback port 8090. These scripts only handle the host
  firewall and the reverse proxy in front of it — they do not install or
  configure PocketCoder itself.
- A second, already-open SSH session before running `harden-host.sh`. It
  rewrites SSH and firewall policy; if something is misconfigured for your
  environment (a non-standard SSH port, a restrictive upstream network
  firewall, etc.), a mistake here can lock you out. Keep a fallback session
  (or your VPS provider's web console) open until you've confirmed you can
  still log in.

## Order to run them in

1. **`sudo ./harden-host.sh --apply`** — run this first, before opening the
   box to the internet on 80/443. It's interactive only in the sense that
   it prints what ports it opened at the end; there are no prompts.
2. Deploy the PocketCoder application stack itself (out of scope for these
   scripts — not covered here).
3. **`sudo ./setup-caddy.sh`** — run this once the app stack is up and
   listening on `127.0.0.1:8090`, so Caddy has something to proxy to
   immediately. It will fail loudly (`exit 1`) if it can't determine the
   box's public IPv4 address after 5 retries; check outbound connectivity
   to `ifconfig.me`/`api.ipify.org`/`icanhazip.com` if that happens.

Both scripts are idempotent enough to re-run (`setup-caddy.sh` skips the
Caddy install if the binary is already present; `harden-host.sh` overwrites
its own config files each run), but neither undoes what the other one did —
there's no corresponding "un-harden" or "remove Caddy" script.

## What you get afterward

- SSH reachable only by key, with Fail2ban banning repeated failures.
- Ports 80 and 443 open; everything else closed at the host firewall,
  including anything else Docker might otherwise expose.
- `https://<your-ip-with-dashes>.sslip.io` serving PocketBase (proxied) and
  `/_pocketcoder/status.json` (served directly from
  `/var/lib/pocketcoder/public/status.json`, refreshed with the current
  Caddy certificate state every 30s via the installed systemd timer).
