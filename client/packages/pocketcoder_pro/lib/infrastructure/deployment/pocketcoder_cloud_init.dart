import 'dart:convert';

import 'package:flutter_aeroform/domain/models/app_bootstrap.dart';

class PocketCoderCloudInit {
  static CloudInitBootstrap build({
    required String adminEmail,
    required String adminPassword,
    required String rootSshKey,
    String sourceCommit = 'main',
  }) {
    for (final value in [adminEmail, adminPassword, rootSshKey, sourceCommit]) {
      if (value.contains('\n') || value.contains('\r')) {
        throw const FormatException('Bootstrap values cannot contain newlines');
      }
    }
    final env = base64Encode(utf8.encode([
      'POCKETBASE_ADMIN_EMAIL=$adminEmail',
      'POCKETBASE_ADMIN_PASSWORD=$adminPassword',
      'root_ssh_key=$rootSshKey',
      'NTFY_ENABLED=false',
    ].join('\n')));
    return CloudInitBootstrap(userData: '''
write_files:
  - path: /usr/local/sbin/pocketcoder-bootstrap
    permissions: '0700'
    content: |
      #!/bin/sh
      set -eu
      install -d -m 0755 /var/lib/pocketcoder/public
      status_file=/var/lib/pocketcoder/public/status.json
      run_id=\$(cat /proc/sys/kernel/random/uuid)
      source_commit='${sourceCommit}'
      current_phase=installing_host
      heartbeat_pid=
      status() {
        current_phase="\$1"
        detail="\${2:-}"
        error="\${3:-}"
        tmp="\$status_file.tmp.\$\$"
        jq -cn --arg runId "\$run_id" --arg phase "\$current_phase" \\
          --arg detail "\$detail" --arg sourceCommit "\$source_commit" \\
          --arg updatedAt "\$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg error "\$error" \\
          '{schema:1,runId:\$runId,phase:\$phase,detail:(if \$detail == "" then null else \$detail end),sourceCommit:\$sourceCommit,updatedAt:\$updatedAt,error:(if \$error == "" then null else \$error end)}' > "\$tmp"
        mv "\$tmp" "\$status_file"
      }
      status_error() {
        status "\$1" failed "\$2"
      }
      heartbeat_start() {
        (while :; do sleep 60; status "\$current_phase" working; done) &
        heartbeat_pid=\$!
      }
      heartbeat_stop() {
        if [ -n "\$heartbeat_pid" ]; then
          kill "\$heartbeat_pid" 2>/dev/null || true
          wait "\$heartbeat_pid" 2>/dev/null || true
          heartbeat_pid=
        fi
      }
      trap 'rc=\$?; heartbeat_stop; if [ "\$rc" -ne 0 ]; then status_error "\$current_phase" bootstrap_failed; fi; exit "\$rc"' EXIT
      status installing_host
      install -d -m 0755 /opt/pocketcoder
      install -d -m 0700 /root/.ssh
      printf '%s' '$env' | base64 -d > /opt/pocketcoder/.env
      chmod 0600 /opt/pocketcoder/.env
      root_ssh_key=\$(sed -n 's/^root_ssh_key=//p' /opt/pocketcoder/.env)
      test -n "\$root_ssh_key"
      printf '%s\\n' "\$root_ssh_key" > /root/.ssh/authorized_keys
      chmod 0600 /root/.ssh/authorized_keys
      sed -i '/^root_ssh_key=/d' /opt/pocketcoder/.env
      # Fill secrets required by docker-compose that the client bootstrap
      # does not generate. Keep these host-local and random; they are not
      # application credentials supplied by the user.
      if ! grep -q '^POCKETBASE_SUPERUSER_EMAIL=' /opt/pocketcoder/.env; then
        cat >> /opt/pocketcoder/.env <<EOF
POCKETBASE_SUPERUSER_EMAIL=superuser@pocketcoder.local
POCKETBASE_SUPERUSER_PASSWORD=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
AGENT_EMAIL=agent@pocketcoder.local
AGENT_PASSWORD=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
GOOSE_ACP_URL=ws://goose:3000/acp
GOOSE_SERVER__SECRET_KEY=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
PN_RELAY_SECRET=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
MCP_GATEWAY_AUTH_TOKEN=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
EOF
      fi
      status fetching_release
      heartbeat_start
      release_base="\${RELEASE_BASE:-https://images.pocketcoder.org}"
      if [ "\$source_commit" = main ]; then
        release_url="\$release_base/release-manifest.json"
      else
        release_url="\$release_base/release-\$source_commit.json"
      fi
      status fetching_release
      if ! release_record=\$(curl -sf --max-time 15 "\$release_url"); then
        heartbeat_stop
        status_error fetching_release release_manifest_unavailable
        exit 1
      fi
      resolved_commit=\$(printf '%s' "\$release_record" | jq -r '.sourceCommit // empty')
      test -n "\$resolved_commit"
      if [ "\$source_commit" = main ]; then
        source_commit="\$resolved_commit"
      fi
      git clone --depth 1 https://github.com/qtpi-bonding-org/pocketcoder.git /opt/pocketcoder/repo
      git -C /opt/pocketcoder/repo fetch --depth 1 origin "\$source_commit"
      git -C /opt/pocketcoder/repo checkout --detach "\$source_commit"
      heartbeat_stop
      cp -a /opt/pocketcoder/repo/. /opt/pocketcoder/
      rm -rf /opt/pocketcoder/repo
      cd /opt/pocketcoder
      if docker compose version >/dev/null 2>&1; then
        compose='docker compose'
      else
        compose='docker-compose'
      fi
      status loading_images
      heartbeat_start
      loaded=0
      cache_url=\$(printf '%s' "\$release_record" | jq -r '.dockerImages.url // empty')
      cache_sha256=\$(printf '%s' "\$release_record" | jq -r '.dockerImages.sha256 // empty')
      cache_file=\$(mktemp)
      printf '%s\\n' "\$release_url" > /var/log/pocketcoder-fetch.log
      if [ -z "\$cache_url" ] || [ -z "\$cache_sha256" ]; then
        rm -f "\$cache_file"
        heartbeat_stop
        status_error loading_images release_bundle_metadata_invalid
        exit 1
      fi
      status downloading_bundle
      # The coupled Docker bundle is several gigabytes. Allow a slow but
      # healthy Linode connection enough time to finish downloading it; this
      # path must never fall back to building images on the VPS.
      if ! curl -sf --max-time 1200 -o "\$cache_file" "\$cache_url"; then
        rm -f "\$cache_file"
        heartbeat_stop
        status_error downloading_bundle release_bundle_download_failed
        exit 1
      fi
      actual_sha256=\$(sha256sum "\$cache_file" | cut -d' ' -f1)
      if [ "\$actual_sha256" != "\$cache_sha256" ]; then
        rm -f "\$cache_file"
        heartbeat_stop
        status_error loading_images release_bundle_checksum_mismatch
        exit 1
      fi
      status loading_bundle
      if ! gunzip -c "\$cache_file" | docker load; then
        rm -f "\$cache_file"
        heartbeat_stop
        status_error loading_bundle release_bundle_load_failed
        exit 1
      fi
      loaded=1
      rm -f "\$cache_file"
      heartbeat_stop
      if [ "\$loaded" -ne 1 ]; then
        status_error loading_images release_bundle_unavailable
        exit 1
      fi
      prebuilt_compose="/opt/pocketcoder/docker-compose.prebuilt.yml"
      sh /opt/pocketcoder/deploy/scripts/resolve-prebuilt-compose.sh \\
        /opt/pocketcoder/docker-compose.yml "\$prebuilt_compose"
      missing_images=0
      missing_image_names=""
      if ! compose_images=\$(sh /opt/pocketcoder/deploy/scripts/list-prebuilt-images.sh "\$prebuilt_compose"); then
        status_error loading_images release_compose_config_failed
        exit 1
      fi
      if [ -z "\$compose_images" ]; then
        status_error loading_images release_compose_images_empty
        exit 1
      fi
      for image in \$compose_images; do
        if ! docker image inspect "\$image" >/dev/null 2>&1; then
          missing_images=1
          missing_image_names="\$missing_image_names \$image"
          printf 'missing prebuilt image: %s\\n' "\$image" >&2
        fi
      done
      if [ "\$missing_images" -ne 0 ]; then
        status_error loading_images "release_bundle_incomplete:\$missing_image_names"
        exit 1
      fi
      status compose_up
      heartbeat_start
      "\$compose" -f "\$prebuilt_compose" up -d --no-build
      heartbeat_stop
      status bootstrap_complete
runcmd:
  - /usr/local/sbin/pocketcoder-bootstrap
''');
  }
}
