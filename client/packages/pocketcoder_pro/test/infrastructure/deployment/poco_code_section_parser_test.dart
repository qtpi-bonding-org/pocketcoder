import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:http/http.dart' as http;
import 'package:pocketcoder_pro/infrastructure/deployment/github_provisioning_source_service.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/poco_code_section_parser.dart';

class _RecordingClient extends http.BaseClient {
  Uri? requestedUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUri = request.url;
    const body = '# POCO:BEGIN sample\nservices: {}\n# POCO:END sample';
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
    );
  }
}

void main() {
  test('extracts marked source with line information', () {
    final sections = PocoCodeSectionParser().parse('''
ignored
# POCO:BEGIN firewall
# POCO:IMPORTANT:BEGIN
networking.firewall.enable = true;
# POCO:IMPORTANT:END
# POCO:END firewall
ignored again
''');

    expect(sections, hasLength(1));
    expect(sections.single.id, 'firewall');
    expect(sections.single.code, 'networking.firewall.enable = true;');
    expect(sections.single.importantCode, 'networking.firewall.enable = true;');
    expect(sections.single.startLine, 3);
    expect(sections.single.endLine, 5);
  });

  test('rejects mismatched and unfinished sections', () {
    expect(
      () => PocoCodeSectionParser().parse(
        '# POCO:BEGIN one\nvalue\n# POCO:END two',
      ),
      throwsFormatException,
    );
    expect(
      () => PocoCodeSectionParser().parse('# POCO:BEGIN one\nvalue'),
      throwsFormatException,
    );
  });

  test('fetches source from the immutable deployed commit', () async {
    final client = _RecordingClient();
    final service = GithubProvisioningSourceService(client: client);

    final sections = await service.fetchSections(
      sourceCommit: 'abc1234',
      file: ProvisioningSourceFile.dockerCompose,
    );

    expect(sections.single.id, 'sample');
    expect(
      client.requestedUri.toString(),
      'https://raw.githubusercontent.com/qtpi-bonding-org/pocketcoder/abc1234/docker-compose.yml',
    );
  });

  test('selects host-specific sources before the shared release sources', () {
    expect(
      provisioningSourceFilesFor(ProvisionBackendKind.nixos),
      [
        ProvisioningSourceFile.hostConfiguration,
        ProvisioningSourceFile.hostBootstrap,
        ProvisioningSourceFile.runtimeEnvironment,
        ProvisioningSourceFile.releaseActivation,
        ProvisioningSourceFile.dockerCompose,
      ],
    );
    expect(
      provisioningSourceFilesFor(ProvisionBackendKind.standardLinux),
      [
        ProvisioningSourceFile.standardLinuxBootstrap,
        ProvisioningSourceFile.runtimeEnvironment,
        ProvisioningSourceFile.releaseActivation,
        ProvisioningSourceFile.dockerCompose,
      ],
    );
  });

  test('rejects a source ref that could alter the GitHub path', () async {
    final service = GithubProvisioningSourceService(
      client: _RecordingClient(),
    );

    expect(
      () => service.fetchSections(
        sourceCommit: '../main',
        file: ProvisioningSourceFile.hostBootstrap,
      ),
      throwsFormatException,
    );
  });

  test('all teaching markers in provisioning source are valid', () async {
    final parser = PocoCodeSectionParser();
    final sourcePaths = [
      '../../../deploy/nixos/configuration.nix',
      '../../../deploy/nixos/bootstrap.sh',
      'assets/deployment/standard_linux_bootstrap.sh',
      '../../../deploy/scripts/prepare-runtime-env.sh',
      '../../../deploy/scripts/activate-release.sh',
      '../../../docker-compose.yml',
    ];

    for (final path in sourcePaths) {
      final source = await File(path).readAsString();
      final sections = parser.parse(source);
      expect(sections, isNotEmpty, reason: path);
      expect(
        sections.every((section) => section.code.trim().isNotEmpty),
        isTrue,
        reason: path,
      );
      expect(
        sections.every((section) => section.importantCode.trim().isNotEmpty),
        isTrue,
        reason: '$path needs a concise excerpt',
      );
    }
  });
}
