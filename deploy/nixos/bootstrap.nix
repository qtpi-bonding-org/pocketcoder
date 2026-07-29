{ config, pkgs, lib, ... }:

{
  systemd.services.pocketcoder-bootstrap = {
    description = "PocketCoder first-boot provisioning";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    before = [ "caddy.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Default (90s) kills this mid-`docker compose up -d`, which builds
      # three images from source (goose is a Rust build) -- leaving the box
      # half-provisioned and the marker file never written.
      TimeoutStartSec = "infinity";
    };
    path = with pkgs; [
      curl
      git
      jq
      coreutils   # base64, date, cut, chmod, mkdir
      gnused      # sed -i
      gnugrep     # grep
      config.virtualisation.docker.package
    ];
    script = ''
      set -euo pipefail

      INSTALL_DIR="/opt/pocketcoder"
      MARKER="$INSTALL_DIR/.initialized"
      # TODO: point at "main" once the goose stack (this branch) merges.
      POCKETCODER_REPO="https://github.com/qtpi-bonding-org/pocketcoder.git"
      POCKETCODER_REF="goose-agui-refactor-plan"

      # Skip if already bootstrapped
      if [ -f "$MARKER" ]; then
        echo "PocketCoder already initialized, skipping bootstrap"
        exit 0
      fi

      echo "Starting PocketCoder first-boot bootstrap..."

      umask 077
      mkdir -p "$INSTALL_DIR"

      # --- Read Linode user-data from metadata service ---
      echo "Fetching user-data from Linode metadata service..."
      USER_DATA=""
      for i in 1 2 3 4 5; do
        USER_DATA=$(curl -sf --max-time 10 \
          -H "Metadata-Token: $(curl -sf --max-time 5 -X PUT -H 'Metadata-Token-Expiry-Seconds: 300' http://169.254.169.254/v1/token)" \
          http://169.254.169.254/v1/user-data || true)
        if [ -n "$USER_DATA" ]; then
          break
        fi
        echo "Attempt $i: metadata not available yet, retrying in 5s..."
        sleep 5
      done

      # Fail closed: a box with no working PocketBase login and no SSH access
      # (no root_ssh_key parsed) is unrecoverable except via Linode Rescue
      # Mode. Better to leave the stack down and loudly say why than to boot
      # a plaintext-credentialed instance nobody can log into.
      if [ -z "$USER_DATA" ]; then
        echo "ERROR: No user-data found from Linode metadata service after 5 attempts." >&2
        echo "Refusing to start the stack with placeholder credentials." >&2
        exit 1
      fi

      echo "Parsing user-data..."
      install -m 600 /dev/null "$INSTALL_DIR/.env"
      base64 -d <<< "$USER_DATA" > "$INSTALL_DIR/.env"

      # Set root SSH key if provided (required -- see fail-closed check below)
      ROOT_SSH_KEY=$(grep '^root_ssh_key=' "$INSTALL_DIR/.env" | cut -d= -f2- || true)
      if [ -z "$ROOT_SSH_KEY" ]; then
        echo "ERROR: user-data had no root_ssh_key. Refusing to start the stack" >&2
        echo "with no way to reach it." >&2
        exit 1
      fi
      mkdir -m 700 -p /root/.ssh
      install -m 600 /dev/null /root/.ssh/authorized_keys
      grep -qxF "$ROOT_SSH_KEY" /root/.ssh/authorized_keys 2>/dev/null || \
        echo "$ROOT_SSH_KEY" >> /root/.ssh/authorized_keys
      sed -i '/^root_ssh_key=/d' "$INSTALL_DIR/.env"

      # --- Fill in secrets docker-compose.yml needs that Aeroform doesn't
      # generate client-side (PocketBase superuser/agent accounts, the
      # c1<->c2 ACP handshake secret). Client-supplied values (admin email
      # etc.) are already in .env from user-data above and are left as-is.
      if ! grep -q '^POCKETBASE_SUPERUSER_EMAIL=' "$INSTALL_DIR/.env"; then
        cat >> "$INSTALL_DIR/.env" <<EOF
      POCKETBASE_SUPERUSER_EMAIL=superuser@pocketcoder.local
      POCKETBASE_SUPERUSER_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
      AGENT_EMAIL=agent@pocketcoder.local
      AGENT_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
      GOOSE_SERVER__SECRET_KEY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
      EOF
      fi

      # --- Clone PocketCoder repo ---
      echo "Cloning PocketCoder repository ($POCKETCODER_REF)..."
      if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        SRC_DIR=$(mktemp -d)
        git clone --depth 1 --branch "$POCKETCODER_REF" "$POCKETCODER_REPO" "$SRC_DIR"
        rm -rf "$SRC_DIR/.git"
        cp -a "$SRC_DIR/." "$INSTALL_DIR/"
        rm -rf "$SRC_DIR"
      fi

      # --- Start PocketCoder stack ---
      echo "Starting PocketCoder stack..."
      cd "$INSTALL_DIR"
      docker compose up -d

      # --- Mark as initialized ---
      date -Iseconds > "$MARKER"
      echo "PocketCoder bootstrap complete"
    '';
  };
}
