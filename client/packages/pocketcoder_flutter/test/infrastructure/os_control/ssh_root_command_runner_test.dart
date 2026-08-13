import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_credentials.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_exception.dart';
import 'package:pocketcoder_flutter/infrastructure/os_control/ssh_root_command_runner.dart';

class _CredentialsProvider implements IRootSshCredentialsProvider {
  const _CredentialsProvider(this.credentials);

  final RootSshCredentials? credentials;

  @override
  Future<RootSshCredentials?> readRootSshCredentials({
    required String instanceId,
  }) async =>
      credentials;
}

SshRootCommandRunner _runner(RootSshCredentials? credentials) =>
    SshRootCommandRunner(
      credentialsProvider: _CredentialsProvider(credentials),
    );

void main() {
  test('refuses a privileged operation without owner credentials', () async {
    await expectLater(
      _runner(null).run(
        instanceId: 'instance',
        host: 'example.com',
        command: RootSshCommand.updatePocketCoder,
      ),
      throwsA(
        isA<RootSshException>().having(
          (error) => error.message,
          'message',
          contains('No stored root credentials'),
        ),
      ),
    );
  });

  test('refuses a privileged operation without a pinned host identity',
      () async {
    await expectLater(
      _runner(
        const RootSshCredentials(
          privateKeyPem: 'not-reached',
          hostKeyType: '',
          hostKeyFingerprint: '',
        ),
      ).run(
        instanceId: 'instance',
        host: 'example.com',
        command: RootSshCommand.updatePocketCoder,
      ),
      throwsA(
        isA<RootSshException>().having(
          (error) => error.message,
          'message',
          contains('SSH identity is missing or invalid'),
        ),
      ),
    );
  });

  test('refuses an invalid private key before connecting', () async {
    await expectLater(
      _runner(
        const RootSshCredentials(
          privateKeyPem: 'not-a-private-key',
          hostKeyType: 'ssh-ed25519',
          hostKeyFingerprint:
              'MD5:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff',
        ),
      ).run(
        instanceId: 'instance',
        host: 'example.com',
        command: RootSshCommand.updatePocketCoder,
      ),
      throwsA(
        isA<RootSshException>().having(
          (error) => error.message,
          'message',
          contains('could not be parsed'),
        ),
      ),
    );
  });
}
