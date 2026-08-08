import 'dart:convert';

import 'package:flutter_aeroform/domain/models/app_bootstrap.dart';

class PocketCoderCloudInit {
  static CloudInitBootstrap build({
    required String adminEmail,
    required String adminPassword,
    required String rootSshKey,
  }) {
    for (final value in [adminEmail, adminPassword, rootSshKey]) {
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
      status_file=/var/lib/pocketcoder/public/status.json
      status() {
        phase="\$1"
        tmp="\$status_file.tmp.\$\$"
        printf '{"schema_version":1,"run_id":"bootstrap","phase":"%s","heartbeat_at":"%s"}\n' "\$phase" "\$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "\$tmp"
        mv "\$tmp" "\$status_file"
      }
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
      status fetching_release
      git clone --depth 1 https://github.com/qtpi-bonding-org/pocketcoder.git /opt/pocketcoder/repo
      cp -a /opt/pocketcoder/repo/. /opt/pocketcoder/
      rm -rf /opt/pocketcoder/repo
      cd /opt/pocketcoder
      status loading_images
      if docker compose version >/dev/null 2>&1; then
        status compose_up
        docker compose up -d
      else
        status compose_up
        docker-compose up -d
      fi
      status bootstrap_complete
runcmd:
  - /usr/local/sbin/pocketcoder-bootstrap
''');
  }
}
