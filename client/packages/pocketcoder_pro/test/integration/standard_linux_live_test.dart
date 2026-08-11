// Gated by the secrets-daemon runner. This test deliberately uses the real
// PocketCoder bootstrap and never asks the VPS to fetch source or build.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_aeroform/domain/cloud_provider/cloud_provider_registry.dart';
import 'package:flutter_aeroform/domain/deployment/deployment_backend_registry.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/host_spec.dart';
import 'package:flutter_aeroform/domain/models/provision_config.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/models/provision_session.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:flutter_aeroform/infrastructure/cloud_provider/linode_api_client.dart';
import 'package:flutter_aeroform/infrastructure/deployment/provisioning_service.dart';
import 'package:flutter_aeroform/infrastructure/deployment/standard_linux_provisioning_strategy.dart';
import 'package:flutter_aeroform/infrastructure/validation/validation_service.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_cloud_init.dart';

const candidate = 'abdec50e07669b07fcc60984b41f137e519235ad';

class _Storage implements ISecureStorage {
  _Storage(this.token);
  final String token;
  @override
  Future<String?> getAccessToken() async => token;
  @override
  Future<InstanceCredentials?> getInstanceCredentials(String _) async => null;
  @override
  Future<ProvisionSession?> getProvisionSession() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<DateTime?> getTokenExpiration() async => null;
  @override
  Future<String?> getCodeVerifier() async => null;
  @override
  Future<void> clearAll() async {}
  @override
  Future<void> clearAuthCredentials() async {}
  @override
  Future<void> clearInstanceSecrets(String _) async {}
  @override
  Future<void> clearProvisionSession(String _) async {}
  @override
  Future<void> storeAccessToken(String _) async {}
  @override
  Future<void> storeCodeVerifier(String _) async {}
  @override
  Future<void> storeInstanceCredentials(InstanceCredentials _) async {}
  @override
  Future<void> storeProvisionSession(ProvisionSession _) async {}
  @override
  Future<void> storeRefreshToken(String _) async {}
  @override
  Future<void> storeTokenExpiration(DateTime _) async {}
}

Future<ProcessResult> _ssh(String key, String ip, String command) =>
    Process.run('ssh', [
      '-q',
      '-i',
      key,
      '-o',
      'StrictHostKeyChecking=no',
      '-o',
      'UserKnownHostsFile=/dev/null',
      '-o',
      'ConnectTimeout=15',
      'root@$ip',
      command,
    ]);

Future<void> _scenario({
  required String name,
  required List<String> harnesses,
  required String token,
}) async {
  final started = DateTime.now().toUtc();
  final key =
      '${Directory.systemTemp.path}/pocketcoder-standard-$pid-${name.replaceAll('-', '')}';
  final publicKeyFile = File('$key.pub');
  final keygen = await Process.run('ssh-keygen', [
    '-q',
    '-t',
    'ed25519',
    '-N',
    '',
    '-f',
    key,
  ]);
  expect(keygen.exitCode, 0, reason: 'ssh-keygen failed for $name');
  final publicKey = (await publicKeyFile.readAsString()).trim();
  final email =
      'pocketcoder-$name-${started.millisecondsSinceEpoch}@example.com';
  final script =
      File('assets/deployment/standard_linux_bootstrap.sh').readAsStringSync();
  final bootstrap = PocketCoderCloudInit.build(
    bootstrapScript: script,
    adminEmail: email,
    adminPassword: 'throwaway-live-password',
    rootSshKey: publicKey,
    sourceCommit: candidate,
    selectedHarnesses: harnesses,
  );
  final client = http.Client();
  final api = LinodeAPIClient(client);
  const strategy = StandardLinuxProvisioningStrategy();
  final service = ProvisioningService(
    providerRegistry: CloudProviderRegistry(
      apiClients: {CloudProviderKind.linode: api},
      oauthServices: const {},
      pullApis: {CloudProviderKind.linode: api},
    ),
    secureStorage: _Storage(token),
    validationService: ValidationService(),
    provisioningStrategy: strategy,
    backendRegistry: DeploymentBackendRegistry({
      ProvisionBackendKind.standardLinux: strategy,
    }),
  );
  final host = GeneratedConfigHostSpec(
    labelPrefix: 'pocketcoder-standard-$name-${started.millisecondsSinceEpoch}',
    authorizedKey: publicKey,
    reverseProxyPort: 8090,
    hostname: HostnameStrategy.sslipIo,
    acmeEmail: email,
    staticPaths: const {'/_pocketcoder': '/var/lib/pocketcoder/public'},
  );
  final config = ProvisionConfig(
    planType: 'g6-standard-1',
    region: 'us-east',
    backend: ProvisionBackendKind.standardLinux,
  );
  String? instanceId;
  final times = <String, DateTime>{'host_create_started': started};
  try {
    final provisioned = await service.provision(
      config,
      host: host,
      appBootstrap: bootstrap,
      onProgress: (p) {
        instanceId = p.instanceId ?? instanceId;
        if (p.phase == ProvisionPhase.hostProvisioned) {
          times['host_created'] = DateTime.now().toUtc();
          print(
            'LIVE $name host_created=${times['host_created']} instance=$instanceId ip=${p.ipAddress}',
          );
        }
      },
    );
    instanceId = provisioned.instanceId;
    final deadline = DateTime.now().toUtc().add(const Duration(minutes: 20));
    Map<String, dynamic>? status;
    http.Response? health;
    final phases = <String>{};
    while (DateTime.now().toUtc().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 10));
      try {
        final response = await client
            .get(
              Uri.parse(
                'https://${provisioned.hostname}/_pocketcoder/status.json',
              ),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          status = jsonDecode(response.body) as Map<String, dynamic>;
          final phase = status['phase'];
          if (phase is String) phases.add(phase);
          print('LIVE $name status=${response.body}');
        }
      } catch (_) {}
      try {
        health = await client
            .get(Uri.parse('https://${provisioned.hostname}/api/health'))
            .timeout(const Duration(seconds: 15));
        if (health.statusCode == 200 && phases.contains('bootstrap_complete'))
          break;
      } catch (_) {}
    }
    times['https_health'] = DateTime.now().toUtc();
    expect(health?.statusCode, 200, reason: '$name HTTPS health failed');
    expect(status?['phase'], 'bootstrap_complete');
    expect(status?['sourceCommit'], candidate);

    final ssh = await _ssh(key, provisioned.ipAddress, r'''
set -eu
test -s /var/lib/pocketcoder/public/status.json
test -s /var/log/pocketcoder-bootstrap-phases.log
test -L /opt/pocketcoder/current
test "$(readlink /opt/pocketcoder/current)" = "/opt/pocketcoder/releases/abdec50e07669b07fcc60984b41f137e519235ad"
! grep -Eiq 'git (clone|pull)|docker (build)|compose (build)|go build|cargo build|flutter build|dart compile' /var/log/cloud-init-output.log /var/log/pocketcoder-bootstrap-phases.log
test "$(docker ps --format '{{.Names}}' | grep -c '^pocketcoder-' || true)" -gt 0
test "$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep -c 'pocketcoder-ollama:' || true)" -eq 0
test "$(find /var/lib/pocketcoder/artifacts -type f | wc -l | tr -d ' ')" -eq 0
''');
    print('LIVE $name ssh stdout=${ssh.stdout} stderr=${ssh.stderr}');
    expect(
      ssh.exitCode,
      0,
      reason: '$name VPS no-build/artifact assertions failed',
    );
    times['ssh'] = DateTime.now().toUtc();
    final trace = await _ssh(
      key,
      provisioned.ipAddress,
      'cat /var/log/pocketcoder-bootstrap-phases.log; docker image ls --format "{{.Repository}}:{{.Tag}}"',
    );
    print(
      'LIVE $name timing host_created=${times['host_created']} health=${times['https_health']} ssh=${times['ssh']}\n${trace.stdout}',
    );
    expect(trace.stdout, contains('detail=downloading:deployment'));
    expect(trace.stdout, contains('pocketcoder-pocketbase:$candidate'));
    expect(trace.stdout, contains('pocketcoder-mcp-gateway:$candidate'));
    for (final harness in harnesses) {
      expect(trace.stdout, contains('pocketcoder-harness-$harness:$candidate'));
    }
    for (final harness in const ['goose', 'claude-code', 'codex', 'opencode']) {
      if (!harnesses.contains(harness)) {
        expect(trace.stdout,
            isNot(contains('pocketcoder-harness-$harness:$candidate')));
      }
    }
  } finally {
    final ownedId = instanceId;
    if (ownedId != null &&
        Platform.environment['AEROFORM_KEEP_INSTANCE'] != '1') {
      await api.deleteInstance(token, ownedId);
      print('LIVE $name deleted instance=$ownedId');
    }
    client.close();
    for (final file in [File(key), publicKeyFile]) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}

void main() {
  final token = Platform.environment['LINODE_TOKEN'];
  final live = Platform.environment['AEROFORM_LIVE_TEST'] == '1';
  test(
    'validates Standard Linux Goose-only and selected peer deployments',
    () async {
      if (!live) return;
      if (token == null || token.isEmpty)
        fail('LINODE_TOKEN must be injected by secrets-daemon');
      final liveToken = token;
      await _scenario(
        name: 'goose-only',
        harnesses: const ['goose'],
        token: liveToken,
      );
      await _scenario(
        name: 'peer-pair',
        harnesses: const ['claude-code', 'codex'],
        token: liveToken,
      );
    },
    skip:
        live ? false : 'Set AEROFORM_LIVE_TEST=1 to run the billed live test.',
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
