import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/infrastructure/git/git_ssh_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/git/git_ssh_repository.dart';

Future<ProcessResult> _run(String exe, List<String> args,
    {String? input}) async {
  final proc = await Process.start(exe, args);
  if (input != null) {
    proc.stdin.write(input);
  }
  await proc.stdin.close();
  final stdout = await proc.stdout.transform(utf8.decoder).join();
  final stderr = await proc.stderr.transform(utf8.decoder).join();
  final code = await proc.exitCode;
  return ProcessResult(proc.pid, code, stdout, stderr);
}

Future<String> _gitSshVolumeName(String userId) async {
  final insp = await _run('docker', [
    'inspect',
    'pocketcoder-pocketbase',
    '--format',
    '{{range .Mounts}}{{.Destination}}={{.Name}}\n{{end}}',
  ]);
  expect(insp.exitCode, 0, reason: insp.stderr);
  final line = (insp.stdout as String)
      .split('\n')
      .firstWhere((l) => l.startsWith('/workspace='));
  final base = line.split('=')[1].trim();
  final namespace = base.endsWith('_workspace')
      ? base.substring(0, base.length - '_workspace'.length)
      : base;
  return '${namespace}_git_ssh_$userId';
}

Future<String?> _readFileFromVolume(String volume, String path) async {
  final result = await _run('docker', [
    'run',
    '--rm',
    '-v',
    '$volume:/state:ro',
    'alpine:3.21',
    'cat',
    '/state/$path',
  ]);
  if (result.exitCode != 0) return null;
  return result.stdout;
}

Future<pocketbase.RecordModel> _waitForStatus(
  pocketbase.PocketBase client,
  String collection,
  String id,
  String field,
  Set<String> terminalValues, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final rec = await client.collection(collection).getOne(id);
    if (terminalValues.contains(rec.get<String>(field))) return rec;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$collection/$id.$field never reached $terminalValues within $timeout');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final superuserEmail = Platform.environment['POCKETBASE_SUPERUSER_EMAIL'];
  final superuserPassword =
      Platform.environment['POCKETBASE_SUPERUSER_PASSWORD'];

  test(
    'a generated key survives multiple reconcile passes and really '
    'authenticates over SSH using the materialized volume contents',
    () async {
      if (superuserEmail == null || superuserPassword == null) {
        markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
            'bring up docker compose (see .env) and export them.');
        return;
      }
      final dockerCheck = await _run('docker', ['version', '--format', 'ok']);
      if (dockerCheck.exitCode != 0) {
        markTestSkipped('docker CLI not usable from this test runner.');
        return;
      }

      final admin = pocketbase.PocketBase(baseUrl);
      await admin
          .collection('_superusers')
          .authWithPassword(superuserEmail, superuserPassword);

      const email = 'git-ssh-e2e-test@pocketcoder.local';
      const password = 'git-ssh-e2e-test-password';
      for (final existing
          in await admin.collection('users').getFullList(
              filter: "email = '$email'")) {
        await admin.collection('users').delete(existing.id);
      }
      final user = await admin.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'role': 'user',
        'verified': true,
      });
      final userId = user.id;
      addTearDown(() => admin.collection('users').delete(userId));

      final verifyClient = pocketbase.PocketBase(baseUrl);
      await verifyClient.collection('users').authWithPassword(email, password);
      final token = verifyClient.authStore.token;
      final authRecord = verifyClient.authStore.record;

      final store = $AuthStore(save: (_) async {});
      store.save(token, authRecord);
      final client = $PocketBase.database(
        baseUrl,
        inMemory: true,
        authStore: store,
        requestPolicy: RequestPolicy.networkFirst,
      );
      addTearDown(client.close);
      final schemaJson = await rootBundle.loadString('assets/pb_schema.json');
      final decoded = jsonDecode(schemaJson);
      final schemaList =
          decoded is Map ? decoded['items'] as List<dynamic> : decoded as List<dynamic>;
      await client.setSchema(jsonEncode(schemaList));

      final repo = GitSshRepository(
        GitSshCredentialDao(client),
        GitRepositoryAccessDao(client),
        client,
      );

      await repo.createAccountKey('e2e account key');
      final accountCred = (await client
              .collection('git_ssh_credentials')
              .getFullList(filter: "user = '$userId'"))
          .single;
      final readyAccount = await _waitForStatus(client, 'git_ssh_credentials',
          accountCred.id, 'status', {'ready', 'error'});
      expect(readyAccount.get<String>('status'), 'ready',
          reason: 'last_error: ${readyAccount.get<String>('last_error')}');
      final publicKey = readyAccount.get<String>('public_key');
      expect(publicKey, isNotEmpty);

      final volume = await _gitSshVolumeName(userId);
      final firstKeyFile =
          await _readFileFromVolume(volume, 'current/keys/${accountCred.id}');
      expect(firstKeyFile, isNotNull,
          reason: 'expected keys/${accountCred.id} in docker volume $volume');
      expect(firstKeyFile, contains('PRIVATE KEY'));

      await repo.addRepositoryAccess(
        provider: GitRepositoryAccessProvider.github,
        repository: 'octocat/hello-world',
        purpose: 'e2e deploy key',
        credentialMode: GitRepositoryAccessCredentialMode.generatedDeploy,
        requestedAccess: GitRepositoryAccessRequestedAccess.readOnly,
      );
      final githubAccess = await client
          .collection('git_repository_access')
          .getFirstListItem(
              "user = '$userId' && repository = 'octocat/hello-world'");
      final readyGithubAccess = await _waitForStatus(client,
          'git_repository_access', githubAccess.id, 'status', {'ready', 'error'});
      expect(readyGithubAccess.get<String>('status'), 'ready',
          reason: 'last_error: ${readyGithubAccess.get<String>('last_error')}');
      final deployCredId = readyGithubAccess.get<String>('credential');
      await _waitForStatus(client, 'git_ssh_credentials', deployCredId,
          'status', {'ready', 'error'});

      // This volume is mounted directly at $HOME/.ssh in the harness
      // container (harnessvolume.GitSSHMount), so ssh/git's own default
      // config/known-hosts lookup needs these at the volume ROOT, not only
      // under current/ -- that's what lets the harness run plain ssh/git
      // with no GIT_SSH_COMMAND override.
      final rootConfig = await _readFileFromVolume(volume, 'config');
      expect(rootConfig, isNotNull,
          reason: 'expected a root-level config symlink into current/, '
              'not just current/config, in docker volume $volume');
      expect(rootConfig, contains('Host pcgit-${readyGithubAccess.id}'));
      final rootKnownHosts = await _readFileFromVolume(volume, 'known_hosts');
      expect(rootKnownHosts, isNotNull,
          reason: 'expected a root-level known_hosts symlink into current/ '
              'in docker volume $volume');

      final firstKeyAfterPass2 =
          await _readFileFromVolume(volume, 'current/keys/${accountCred.id}');
      expect(firstKeyAfterPass2, firstKeyFile,
          reason: 'the account key from pass 1 must survive a pass that '
              "didn't regenerate it");
      final deployKeyFile =
          await _readFileFromVolume(volume, 'current/keys/$deployCredId');
      expect(deployKeyFile, isNotNull);
      expect(deployKeyFile, contains('PRIVATE KEY'));

      final sshdName = 'pc-e2e-sshd-${DateTime.now().millisecondsSinceEpoch}';
      final startSshd = await _run('docker', [
        'run',
        '-d',
        '--name',
        sshdName,
        '--network',
        'pocketcoder-agent',
        '-p',
        '0:22',
        '-e',
        'AUTHORIZED_KEY=$publicKey',
        'alpine:3.21',
        'sh',
        '-c',
        'apk add --no-cache openssh-server >/tmp/apk.log 2>&1 && '
            'ssh-keygen -A && '
            'mkdir -p /root/.ssh && '
            'echo "\$AUTHORIZED_KEY" > /root/.ssh/authorized_keys && '
            'chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && '
            'exec /usr/sbin/sshd -D -p 22 -o PermitRootLogin=yes '
            '-o PasswordAuthentication=no -o StrictModes=no',
      ]);
      expect(startSshd.exitCode, 0, reason: startSshd.stderr);
      addTearDown(() => _run('docker', ['rm', '-f', sshdName]));

      String? hostPort;
      for (var attempt = 0; attempt < 30; attempt++) {
        final portResult = await _run('docker', ['port', sshdName, '22']);
        if (portResult.exitCode == 0 && portResult.stdout.trim().isNotEmpty) {
          hostPort = portResult.stdout.trim().split(':').last;
          final probe =
              await _run('docker', ['exec', sshdName, 'pgrep', 'sshd']);
          if (probe.exitCode == 0) break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(hostPort, isNotNull, reason: 'sshd never came up in $sshdName');

      await repo.addRepositoryAccess(
        provider: GitRepositoryAccessProvider.custom,
        repository: 'e2e/repo',
        purpose: 'e2e custom host',
        credentialMode: GitRepositoryAccessCredentialMode.existingAccount,
        credential: accountCred.id,
        requestedAccess: GitRepositoryAccessRequestedAccess.readOnly,
        host: sshdName,
        port: 22,
      );
      final customAccess = await client
          .collection('git_repository_access')
          .getFirstListItem("user = '$userId' && repository = 'e2e/repo'");
      final readyCustomAccess = await _waitForStatus(client,
          'git_repository_access', customAccess.id, 'status', {'ready', 'error'});
      expect(readyCustomAccess.get<String>('status'), 'ready',
          reason: 'last_error: ${readyCustomAccess.get<String>('last_error')}');
      expect(readyCustomAccess.get<String>('known_host_key'), isNotEmpty,
          reason: 'expected ProbeHostKey to have pinned a real host key');

      final firstKeyAfterPass3 =
          await _readFileFromVolume(volume, 'current/keys/${accountCred.id}');
      expect(firstKeyAfterPass3, firstKeyFile);

      final keyPath =
          '${Directory.systemTemp.path}/pc-e2e-key-${accountCred.id}';
      await File(keyPath).writeAsString(firstKeyFile!);
      await _run('chmod', ['600', keyPath]);
      addTearDown(() => File(keyPath).delete());

      final sshResult = await _run('ssh', [
        '-i', keyPath,
        '-p', hostPort!,
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'ConnectTimeout=10',
        'root@127.0.0.1',
        'echo E2E_SSH_CONNECTED',
      ]);
      expect(sshResult.stdout, contains('E2E_SSH_CONNECTED'),
          reason: 'ssh stderr: ${sshResult.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
