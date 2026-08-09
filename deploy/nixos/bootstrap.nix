{ config, pkgs, lib, sourceCommit ? "main", ... }:

{
  systemd.services.pocketcoder-bootstrap = {
    description = "PocketCoder first-boot provisioning";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network-online.target" "caddy.service" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Provisioning includes image loading and may take longer than the
      # default systemd service timeout.
      TimeoutStartSec = "infinity";
    };
    path = with pkgs; [
      curl
      git
      jq
      coreutils   # base64, date, cut, chmod, mkdir
      gnused      # sed -i
      gnugrep     # grep
      gawk        # compose-file image tag rewriting
      gzip        # gunzip -c (Docker image cache)
      config.virtualisation.docker.package
    ];
    script = ''
      set -euo pipefail

      INSTALL_DIR="/opt/pocketcoder"
      MARKER="$INSTALL_DIR/.initialized"
      POCKETCODER_REPO="https://github.com/qtpi-bonding-org/pocketcoder.git"
      # The release image embeds the exact source revision that produced it.
      # CI writes deploy/nixos/release-commit.nix before building. Development
      # images use the local default (main).
      POCKETCODER_REF="${sourceCommit}"
      export PC_SOURCE_COMMIT="$POCKETCODER_REF"

      # Skip if already bootstrapped
      if [ -f "$MARKER" ]; then
        echo "PocketCoder already initialized, skipping bootstrap"
        exit 0
      fi

      source /etc/pocketcoder/status.sh
      trap 'pc_status_error "$PC_CURRENT_PHASE" "step failed at line ''${BASH_LINENO[0]}"' ERR
      pc_status_init

      echo "Starting PocketCoder first-boot bootstrap..."

      umask 077
      mkdir -p "$INSTALL_DIR"

      # --- Read admin config: boot-time-pull disk file, or (legacy
      # CustomImageProvisioningStrategy) Linode metadata service ---
      #
      # The boot-time-pull installer StackScript writes this file directly
      # onto the target disk (deploy/nixos/stackscripts/
      # pocketcoder-image-installer.sh) instead of using Linode's
      # metadata.user_data -- confirmed via live testing that a
      # disk-create-time StackScript never runs at all when
      # metadata.user_data is also set on the instance (Linode limitation,
      # not a bug here). CustomImageProvisioningStrategy never touches a
      # StackScript, so it has no such conflict and still uses metadata
      # normally -- this file being absent is how bootstrap.nix tells the
      # two paths apart.
      BOOTSTRAP_ENV_FILE="/var/lib/pocketcoder-bootstrap-env"
      echo "Checking for $BOOTSTRAP_ENV_FILE: $([ -f "$BOOTSTRAP_ENV_FILE" ] && echo "found, $(wc -c < "$BOOTSTRAP_ENV_FILE") bytes" || echo "not present")"
      if [ -f "$BOOTSTRAP_ENV_FILE" ]; then
        echo "Reading admin config from $BOOTSTRAP_ENV_FILE (boot-time-pull path)..."
        install -m 600 /dev/null "$INSTALL_DIR/.env"
        cp "$BOOTSTRAP_ENV_FILE" "$INSTALL_DIR/.env"
        chmod 600 "$INSTALL_DIR/.env"
        # Consumed once -- don't leave the admin password sitting in
        # plaintext on disk any longer than necessary.
        shred -u "$BOOTSTRAP_ENV_FILE" 2>/dev/null || rm -f "$BOOTSTRAP_ENV_FILE"
      elif [ -f "$INSTALL_DIR/.env" ]; then
        # A power-cycle can interrupt bootstrap after the one-shot env file
        # has been consumed. Resume from the protected application env rather
        # than falling back to metadata or losing the deployment entirely.
        echo "Resuming bootstrap from existing $INSTALL_DIR/.env..."
        chmod 600 "$INSTALL_DIR/.env"
      else
        echo "Fetching user-data from Linode metadata service (legacy custom-image path)..."
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

        # Fail closed: a box with no working PocketBase login and no SSH
        # access (no root_ssh_key parsed) is unrecoverable except via
        # Linode Rescue Mode. Better to leave the stack down and loudly
        # say why than to boot a plaintext-credentialed instance nobody
        # can log into.
        if [ -z "$USER_DATA" ]; then
          echo "ERROR: No user-data found from Linode metadata service after 5 attempts." >&2
          echo "Refusing to start the stack with placeholder credentials." >&2
          exit 1
        fi

        echo "Parsing user-data..."
        install -m 600 /dev/null "$INSTALL_DIR/.env"
        base64 -d <<< "$USER_DATA" > "$INSTALL_DIR/.env"
      fi

      # Set root SSH key if provided (required -- see fail-closed check below)
      ROOT_SSH_KEY=$(grep '^root_ssh_key=' "$INSTALL_DIR/.env" | cut -d= -f2- || true)
      if [ -z "$ROOT_SSH_KEY" ] && [ ! -s /root/.ssh/authorized_keys ]; then
        echo "ERROR: user-data had no root_ssh_key. Refusing to start the stack" >&2
        echo "with no way to reach it." >&2
        exit 1
      fi
      mkdir -m 700 -p /root/.ssh
      if [ -n "$ROOT_SSH_KEY" ]; then
        install -m 600 /dev/null /root/.ssh/authorized_keys
        echo "$ROOT_SSH_KEY" >> /root/.ssh/authorized_keys
        sed -i '/^root_ssh_key=/d' "$INSTALL_DIR/.env"
      fi

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
PN_RELAY_SECRET=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
MCP_GATEWAY_AUTH_TOKEN=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
EOF
      fi

      # --- Clone PocketCoder repo ---
      # Keeps .git (unlike earlier versions of this script, which stripped
      # it) so /opt/pocketcoder is a real, working clone with `origin`
      # already configured -- the update feature (git pull && docker
      # compose build && docker compose up -d, triggered by the owner from
      # the app) depends on this being a real git repo already pointed at
      # the right remote/branch, not something set up by hand later.
      # Clones to a temp dir first rather than directly into $INSTALL_DIR
      # because $INSTALL_DIR already has .env written into it above, and
      # `git clone` refuses to target a non-empty directory.
      echo "Cloning PocketCoder repository ($POCKETCODER_REF)..."
      pc_status_phase fetching_release
      pc_status_heartbeat_start
      if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        SRC_DIR=$(mktemp -d)
        # `POCKETCODER_REF` is normally a 40-character commit SHA. `git
        # clone --branch` does not accept raw SHAs, so fetch the exact object
        # explicitly and detach at it. This also works for the local default
        # branch used by development images.
        git clone --depth 1 "$POCKETCODER_REPO" "$SRC_DIR"
        git -C "$SRC_DIR" fetch --depth 1 origin "$POCKETCODER_REF"
        git -C "$SRC_DIR" checkout --detach "$POCKETCODER_REF"
        cp -a "$SRC_DIR/." "$INSTALL_DIR/"
        rm -rf "$SRC_DIR"
      fi
      pc_status_heartbeat_stop

      # --- Load the pre-built Docker image bundle from the coupled release. ---
      # The CI docker-images job publishes the exact bundle for this source
      # revision. A missing or invalid bundle is fatal: provisioning must
      # never turn into an unplanned source build on a user's VPS.
      pc_status_phase loading_images
      pc_status_heartbeat_start
      RELEASE_BASE="''${RELEASE_BASE:-https://images.pocketcoder.org}"
      if [ "$POCKETCODER_REF" = "main" ]; then
        RELEASE_URL="$RELEASE_BASE/release-manifest.json"
      else
        RELEASE_URL="$RELEASE_BASE/release-$POCKETCODER_REF.json"
      fi
      LOADED=0
      pc_status_phase loading_images fetching_manifest
      if ! RECORD=$(curl -sf --max-time 15 "$RELEASE_URL"); then
        pc_status_heartbeat_stop
        pc_status_error loading_images "release_manifest_unavailable"
        exit 1
      fi
      CACHE_URL=$(echo "$RECORD" | jq -r '.dockerImages.url // empty')
      CACHE_SHA256=$(echo "$RECORD" | jq -r '.dockerImages.sha256 // empty')
      CACHE_FILE=$(mktemp)
      echo "$RELEASE_URL" > /var/log/pocketcoder-fetch.log
      if [ -z "$CACHE_URL" ] || [ -z "$CACHE_SHA256" ]; then
        rm -f "$CACHE_FILE"
        pc_status_heartbeat_stop
        pc_status_error loading_images "release_bundle_metadata_invalid"
        exit 1
      fi
      pc_status_phase loading_images downloading_bundle
      # The coupled Docker bundle is several gigabytes. Allow a slow but
      # healthy Linode connection enough time to finish downloading it; this
      # path must never fall back to building images on the VPS.
      if ! curl -sf --max-time 1200 -o "$CACHE_FILE" "$CACHE_URL"; then
        rm -f "$CACHE_FILE"
        pc_status_heartbeat_stop
        pc_status_error loading_images "release_bundle_download_failed"
        exit 1
      fi
      ACTUAL_SHA256=$(sha256sum "$CACHE_FILE" | cut -d' ' -f1)
      if [ "$ACTUAL_SHA256" != "$CACHE_SHA256" ]; then
        rm -f "$CACHE_FILE"
        pc_status_heartbeat_stop
        pc_status_error loading_images "release_bundle_checksum_mismatch"
        exit 1
      fi
      pc_status_phase loading_images loading_bundle
      if ! gunzip -c "$CACHE_FILE" | docker load; then
        rm -f "$CACHE_FILE"
        pc_status_heartbeat_stop
        pc_status_error loading_images "release_bundle_load_failed"
        exit 1
      fi
      LOADED=1
      rm -f "$CACHE_FILE"
      if [ "$LOADED" -ne 1 ]; then
        pc_status_heartbeat_stop
        pc_status_error loading_images "release_bundle_unavailable"
        exit 1
      fi
      PREBUILT_COMPOSE="$INSTALL_DIR/docker-compose.prebuilt.yml"
      sh "$INSTALL_DIR/deploy/scripts/resolve-prebuilt-compose.sh" \
        "$INSTALL_DIR/docker-compose.yml" "$PREBUILT_COMPOSE"
      MISSING_IMAGES=0
      MISSING_IMAGE_NAMES=""
      if ! COMPOSE_IMAGES=$(docker compose -f "$PREBUILT_COMPOSE" config --images); then
        pc_status_heartbeat_stop
        pc_status_error loading_images "release_compose_config_failed"
        exit 1
      fi
      if [ -z "$COMPOSE_IMAGES" ]; then
        pc_status_heartbeat_stop
        pc_status_error loading_images "release_compose_images_empty"
        exit 1
      fi
      for IMAGE in $COMPOSE_IMAGES; do
        if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
          MISSING_IMAGES=1
          MISSING_IMAGE_NAMES="$MISSING_IMAGE_NAMES $IMAGE"
          echo "missing prebuilt image: $IMAGE" >&2
        fi
      done
      if [ "$MISSING_IMAGES" -ne 0 ]; then
        pc_status_heartbeat_stop
        _pc_status_write loading_images "missing prebuilt images:''${MISSING_IMAGE_NAMES}" "release_bundle_incomplete"
        exit 1
      fi
      pc_status_heartbeat_stop

      # --- Start PocketCoder stack without building on the VPS. ---
      echo "Starting PocketCoder stack..."
      pc_status_phase compose_up
      pc_status_heartbeat_start
      cd "$INSTALL_DIR"

      # Claude Code, Codex, and OpenCode are provisioned lazily by PocketBase,
      # but their first-party images must already exist locally: their catalog
      # entries intentionally use local PocketCoder tags rather than a public
      # registry.
      docker compose -f docker-compose.prebuilt.yml up -d --no-build
      pc_status_heartbeat_stop

      # --- Mark as initialized ---
      pc_status_phase bootstrap_complete
      date -Iseconds > "$MARKER"
      echo "PocketCoder bootstrap complete"
    '';
  };
  environment.etc."pocketcoder/status.sh".source = ./status.sh;
}
