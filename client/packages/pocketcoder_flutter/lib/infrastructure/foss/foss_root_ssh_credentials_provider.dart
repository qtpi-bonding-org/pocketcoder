import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_credentials.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';

class FossRootSshCredentialsProvider implements IRootSshCredentialsProvider {
  const FossRootSshCredentialsProvider(this._store);

  final FossRootSshCredentialsStore _store;

  @override
  Future<RootSshCredentials?> readRootSshCredentials({
    required String instanceId,
  }) async {
    final credentials = await _store.load();
    if (credentials == null) return null;
    return RootSshCredentials(
      privateKeyPem: credentials.privateKey,
      hostKeyType: credentials.hostKeyType,
      hostKeyFingerprint: credentials.hostKeyFingerprint,
      publicKeyOpenSsh: credentials.publicKey,
    );
  }
}
