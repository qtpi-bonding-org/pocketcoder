{ config, pkgs, lib, sourceCommit ? "main", ... }:

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

      # Skip if already bootstrapped
      if [ -f "$MARKER" ]; then
        echo "PocketCoder already initialized, skipping bootstrap"
        exit 0
      fi

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
PN_RELAY_SECRET=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
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

      # --- Try to load pre-built Docker images from R2 cache (optional
      # speed-up) ---
      # nixos-image.yml's docker-images job pre-builds and caches the core
      # services plus Ollama and optional harness images in the same R2 bucket as the
      # NixOS image itself, tagged to match exactly what `docker compose
      # up -d` below would build on its own (see that job's -p pocketcoder
      # project-name pin). This is purely best-effort: any failure here
      # (no manifest published yet, sha256 mismatch, network hiccup) just
      # falls through to `docker compose up -d` building from source, same
      # as it always has -- this step must never fail the bootstrap.
      echo "Checking for cached Docker images..."
      DOCKER_CACHE_URL="https://images.pocketcoder.org/docker-images-manifest.json"
      if MANIFEST=$(curl -sf --max-time 15 "$DOCKER_CACHE_URL"); then
        CACHE_URL=$(echo "$MANIFEST" | jq -r '.url')
        CACHE_SHA256=$(echo "$MANIFEST" | jq -r '.sha256')
        CACHE_SOURCE_COMMIT=$(echo "$MANIFEST" | jq -r '.sourceCommit // empty')
        CACHE_FILE=$(mktemp)
        if [ "$CACHE_SOURCE_COMMIT" != "$POCKETCODER_REF" ]; then
          echo "Cached Docker image source mismatch (expected $POCKETCODER_REF, got ''${CACHE_SOURCE_COMMIT:-missing}) -- building from source."
        elif curl -sf --max-time 180 -o "$CACHE_FILE" "$CACHE_URL"; then
          ACTUAL_SHA256=$(sha256sum "$CACHE_FILE" | cut -d' ' -f1)
          if [ "$ACTUAL_SHA256" = "$CACHE_SHA256" ]; then
            if gunzip -c "$CACHE_FILE" | docker load; then
              echo "Loaded cached Docker images (sha256 verified)."
            else
              echo "docker load failed on cached images -- falling back to source build."
            fi
          else
            echo "Cached image sha256 mismatch (expected $CACHE_SHA256, got $ACTUAL_SHA256) -- falling back to source build."
          fi
        else
          echo "Failed to download cached Docker images -- falling back to source build."
        fi
        rm -f "$CACHE_FILE"
      else
        echo "No Docker image cache manifest available -- building from source."
      fi

      # --- Start PocketCoder stack ---
      # Uses any images loaded above as-is; `docker compose` only builds a
      # service whose image isn't already present locally, so a
      # successful cache load above makes this a no-op build.
      echo "Starting PocketCoder stack..."
      cd "$INSTALL_DIR"

      # Claude Code, Codex, and OpenCode are provisioned lazily by PocketBase,
      # but their first-party images must already exist locally: their catalog
      # entries intentionally use local PocketCoder tags rather than a public
      # registry.
      # The release image cache normally provides them; source deployments and
      # cache misses build them here once before the stack starts.
      if ! docker image inspect pocketcoder-harness-claude-code:0.64.2 >/dev/null 2>&1 || \
         ! docker image inspect pocketcoder-harness-codex:1.1.9 >/dev/null 2>&1 || \
         ! docker image inspect pocketcoder-harness-opencode:1.18.11 >/dev/null 2>&1; then
        echo "Building optional ACP harness images..."
        docker compose --profile harness-images build claude-code-harness-image codex-harness-image opencode-harness-image
      fi

      docker compose up -d

      # --- Mark as initialized ---
      date -Iseconds > "$MARKER"
      echo "PocketCoder bootstrap complete"
    '';
  };
}
