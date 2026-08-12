import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/github_provisioning_source_service.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/walkthrough_panel.dart';

class _SourceClient extends http.BaseClient {
  final requestedPaths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    final path = request.url.path;
    final body = switch (path) {
      final value when value.endsWith('/deploy/nixos/configuration.nix') => '''
# POCO:BEGIN vps-public-firewall
networking.firewall.enable = true;
# POCO:END vps-public-firewall
''',
      final value when value.endsWith('/deploy/nixos/bootstrap.sh') => '''
# POCO:BEGIN bootstrap-release-source
git checkout --detach sourceCommit
# POCO:END bootstrap-release-source
''',
      final value when value.endsWith('/standard_linux_bootstrap.sh') => '''
# POCO:BEGIN bootstrap-owner-config
install -m 0600 owner.env
# POCO:END bootstrap-owner-config
# POCO:BEGIN bootstrap-release-source
curl immutable-release
# POCO:END bootstrap-release-source
''',
      final value when value.endsWith('/prepare-runtime-env.sh') => '''
# POCO:BEGIN bootstrap-local-secrets
chmod 0600 runtime.env
# POCO:END bootstrap-local-secrets
''',
      final value when value.endsWith('/activate-release.sh') => '''
# POCO:BEGIN bootstrap-verified-images
sha256sum image.tar
# POCO:END bootstrap-verified-images
# POCO:BEGIN bootstrap-compose-start
docker compose up -d
# POCO:END bootstrap-compose-start
''',
      _ => '''
# POCO:BEGIN compose-pocketbase
services:
  pocketbase: {}
# POCO:END compose-pocketbase
''',
    };
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
  }
}

void main() {
  testWidgets('shows code from the exact commit and selects the live stage',
      (tester) async {
    final client = _SourceClient();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WalkthroughPanel(
          stage: OnboardingStage.fetchingRelease,
          sourceCommit: 'abcdef1234567',
          sourceService: GithubProvisioningSourceService(client: client),
          backend: ProvisionBackendKind.nixos,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('THE EXACT RELEASE SOURCE'), findsOneWidget);
    expect(find.textContaining('git checkout --detach'), findsOneWidget);
    expect(
      client.requestedPaths,
      everyElement(contains('/abcdef1234567/')),
    );
    expect(client.requestedPaths, hasLength(5));
  });

  testWidgets(
      'standard Linux shows its bootstrap script and never requests NixOS source',
      (tester) async {
    final client = _SourceClient();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WalkthroughPanel(
          stage: OnboardingStage.installingHost,
          sourceCommit: 'abcdef1234567',
          sourceService: GithubProvisioningSourceService(client: client),
          backend: ProvisionBackendKind.standardLinux,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('RECEIVING YOUR CONFIGURATION'), findsOneWidget);
    expect(find.textContaining('install -m 0600 owner.env'), findsOneWidget);
    expect(
      client.requestedPaths,
      contains(contains('/standard_linux_bootstrap.sh')),
    );
    expect(
      client.requestedPaths.where((path) => path.contains('/deploy/nixos/')),
      isEmpty,
    );
    expect(client.requestedPaths, hasLength(4));
  });
}
