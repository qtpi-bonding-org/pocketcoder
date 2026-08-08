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
      'ADMIN_EMAIL=$adminEmail',
      'ADMIN_PASSWORD=$adminPassword',
      'ROOT_SSH_KEY=$rootSshKey',
    ].join('\n')));
    return CloudInitBootstrap(userData: '''
write_files:
  - path: /usr/local/sbin/application-bootstrap
    permissions: '0700'
    content: |
      #!/bin/sh
      set -eu
      install -d -m 0755 /var/lib/application/public
      printf '%s' '$env' | base64 -d > /var/lib/application/bootstrap.env
      chmod 0600 /var/lib/application/bootstrap.env
      # The host layer has already started the native reverse proxy.
      # The application owns status phase publication from this point.
      printf '%s\\n' installing_host > /var/lib/application/public/status.trace
runcmd:
  - /usr/local/sbin/application-bootstrap
''');
  }
}
