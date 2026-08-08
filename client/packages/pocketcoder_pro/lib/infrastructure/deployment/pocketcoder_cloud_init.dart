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
      install -d -m 0755 /opt/pocketcoder
      install -d -m 0700 /root/.ssh
      printf '%s' '$env' | base64 -d > /opt/pocketcoder/.env
      chmod 0600 /opt/pocketcoder/.env
      root_ssh_key=\$(sed -n 's/^root_ssh_key=//p' /opt/pocketcoder/.env)
      test -n "\$root_ssh_key"
      printf '%s\\n' "\$root_ssh_key" > /root/.ssh/authorized_keys
      chmod 0600 /root/.ssh/authorized_keys
      sed -i '/^root_ssh_key=/d' /opt/pocketcoder/.env
      git clone --depth 1 https://github.com/qtpi-bonding-org/pocketcoder.git /opt/pocketcoder/repo
      cp -a /opt/pocketcoder/repo/. /opt/pocketcoder/
      rm -rf /opt/pocketcoder/repo
      cd /opt/pocketcoder
      if docker compose version >/dev/null 2>&1; then
        docker compose up -d
      else
        docker-compose up -d
      fi
runcmd:
  - /usr/local/sbin/pocketcoder-bootstrap
''');
  }
}
