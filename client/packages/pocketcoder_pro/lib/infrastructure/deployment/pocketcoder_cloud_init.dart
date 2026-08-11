import 'dart:convert';

import 'package:flutter_aeroform/domain/models/app_bootstrap.dart';
import 'package:pocketcoder_pro/domain/deployment/harness_catalog.dart';

/// Packages the static Standard Linux bootstrap asset as cloud-init data.
///
/// Shell behavior belongs in the asset, not in Dart. Deployment-specific data
/// is delivered in separate base64-encoded files so it is never interpolated
/// into executable shell source.
class PocketCoderCloudInit {
  static const bootstrapAssetPath =
      'packages/pocketcoder_pro/assets/deployment/standard_linux_bootstrap.sh';
  static const caddyfileTemplateAssetPath =
      'packages/pocketcoder_pro/assets/deployment/Caddyfile.template';

  static final _releaseCommit = RegExp(r'^[0-9a-f]{40}$');

  static CloudInitBootstrap build({
    required String bootstrapScript,
    required String adminEmail,
    required String adminPassword,
    required String rootSshKey,
    String sourceCommit = 'main',
    Iterable<String>? selectedHarnesses,
  }) {
    for (final value in [adminEmail, adminPassword, rootSshKey]) {
      if (value.contains('\n') || value.contains('\r')) {
        throw const FormatException('Bootstrap values cannot contain newlines');
      }
    }
    if (sourceCommit != 'main' && !_releaseCommit.hasMatch(sourceCommit)) {
      throw const FormatException(
        'Release reference must be main or a 40-character lowercase commit',
      );
    }
    if (bootstrapScript.trim().isEmpty ||
        !bootstrapScript.startsWith('#!/bin/sh')) {
      throw const FormatException('Standard Linux bootstrap script is invalid');
    }

    final catalog = DeploymentHarnessCatalog.bundled;
    final selected = catalog.canonicalize(
      selectedHarnesses ?? catalog.initialSelection,
    );
    final runtimeEnv = [
      'POCKETBASE_ADMIN_EMAIL=$adminEmail',
      'POCKETBASE_ADMIN_PASSWORD=$adminPassword',
      'root_ssh_key=$rootSshKey',
      'NTFY_ENABLED=false',
      'POCKETCODER_SELECTED_HARNESSES=${selected.join(',')}',
      'POCKETCODER_RELEASE_STATE_DIR=/var/lib/pocketcoder/release',
      'POCKETCODER_ARTIFACT_DIR=/var/lib/pocketcoder/artifacts',
    ].join('\n');
    final bootstrapConfig = jsonEncode({
      'schemaVersion': 1,
      'requestedCommit': sourceCommit,
      'selectedHarnesses': selected,
    });

    return CloudInitBootstrap(userData: '''
write_files:
  - path: /usr/local/sbin/pocketcoder-bootstrap
    permissions: '0700'
    encoding: b64
    content: ${base64Encode(utf8.encode(bootstrapScript))}
  - path: /var/lib/pocketcoder/config/runtime.env
    permissions: '0600'
    encoding: b64
    content: ${base64Encode(utf8.encode(runtimeEnv))}
  - path: /var/lib/pocketcoder/config/bootstrap.json
    permissions: '0600'
    encoding: b64
    content: ${base64Encode(utf8.encode(bootstrapConfig))}
runcmd:
  - /usr/local/sbin/pocketcoder-bootstrap
''');
  }
}
