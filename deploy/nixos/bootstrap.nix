{ config, pkgs, lib, ... }:

{
  systemd.services.pocketcoder-bootstrap = {
    description = "PocketCoder first-boot provisioning";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "caddy.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      curl
      git
      jq
      coreutils   # base64, date, cut, chmod, mkdir
      gnused      # sed -i
      gnugrep     # grep
      shadow      # chpasswd
      config.virtualisation.docker.package
    ];
    script = ''
      set -euo pipefail

      INSTALL_DIR="/opt/pocketcoder"
      MARKER="$INSTALL_DIR/.initialized"

      # Skip if already bootstrapped
      if [ -f "$MARKER" ]; then
        echo "PocketCoder already initialized, skipping bootstrap"
        exit 0
      fi

      echo "Starting PocketCoder first-boot bootstrap..."

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

      if [ -z "$USER_DATA" ]; then
        echo "WARNING: No user-data found. Writing default .env"
        cat > "$INSTALL_DIR/.env" <<'ENVEOF'
      POCKETBASE_SUPERUSER_EMAIL=superuser@pocketcoder.local
      POCKETBASE_SUPERUSER_PASSWORD=changeme
      POCKETBASE_ADMIN_EMAIL=human@pocketcoder.local
      POCKETBASE_ADMIN_PASSWORD=changeme
      AGENT_EMAIL=poco@pocketcoder.local
      AGENT_PASSWORD=changeme
      ENABLE_GO_RELAY=true
      OPENCODE_URL=http://opencode:3000
      ENVEOF
      else
        echo "Parsing user-data..."

        # User-data is a base64-encoded env file
        echo "$USER_DATA" | base64 -d > "$INSTALL_DIR/.env"

        # Set root password if provided in user-data
        ROOT_PASSWORD=$(grep '^root_password=' "$INSTALL_DIR/.env" | cut -d= -f2- || true)
        if [ -n "$ROOT_PASSWORD" ]; then
          echo "root:$ROOT_PASSWORD" | chpasswd
          # Remove root_password from .env (not needed by docker compose)
          sed -i '/^root_password=/d' "$INSTALL_DIR/.env"
        fi

        # Set root SSH key if provided
        ROOT_SSH_KEY=$(grep '^root_ssh_key=' "$INSTALL_DIR/.env" | cut -d= -f2- || true)
        if [ -n "$ROOT_SSH_KEY" ]; then
          mkdir -p /root/.ssh
          echo "$ROOT_SSH_KEY" >> /root/.ssh/authorized_keys
          chmod 700 /root/.ssh
          chmod 600 /root/.ssh/authorized_keys
          sed -i '/^root_ssh_key=/d' "$INSTALL_DIR/.env"
        fi
      fi

      # --- Clone PocketCoder repo ---
      echo "Cloning PocketCoder repository..."
      if [ ! -d "$INSTALL_DIR/.git" ]; then
        git clone https://github.com/pocketcoder-app/pocketcoder.git "$INSTALL_DIR/repo"
        # Move repo contents to install dir (keep .env we already wrote)
        cp "$INSTALL_DIR/.env" "$INSTALL_DIR/repo/.env"
        mv "$INSTALL_DIR/repo/"* "$INSTALL_DIR/repo/".* "$INSTALL_DIR/" 2>/dev/null || true
        rm -rf "$INSTALL_DIR/repo"
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
