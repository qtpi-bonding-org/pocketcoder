import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/domain/deployment/readiness_update.dart';

/// Never overwrites an already-pinned fingerprint (TOFU -- trust on first
/// use only).
Future<void> captureSshHostIdentity({
  required ISecureStorage secureStorage,
  required String instanceId,
  required ReadinessUpdate update,
}) async {
  final hostKey = update.statusDocument?.sshHostKey;
  if (hostKey == null) return;
  final credentials = await secureStorage.getInstanceCredentials(instanceId);
  if (credentials == null) return;
  final pinned = credentials.rootSshHostKeyFingerprint;
  if (pinned != null && pinned.isNotEmpty) return;
  await secureStorage.storeInstanceCredentials(
    credentials.copyWith(
      rootSshHostKeyType: hostKey.type,
      rootSshHostKeyFingerprint: hostKey.fingerprint,
    ),
  );
}
