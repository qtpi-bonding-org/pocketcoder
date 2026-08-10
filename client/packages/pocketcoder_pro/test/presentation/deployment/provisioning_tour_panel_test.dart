import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/github_provisioning_source_service.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/provisioning_tour_panel.dart';

class _SourceClient extends http.BaseClient {
  final requestedPaths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    final body = switch (request.url.pathSegments.last) {
      'configuration.nix' => '''
# POCO:BEGIN vps-public-firewall
networking.firewall.enable = true;
# POCO:END vps-public-firewall
''',
      'bootstrap.nix' => '''
# POCO:BEGIN bootstrap-release-source
git checkout --detach sourceCommit
# POCO:END bootstrap-release-source
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
        body: ProvisioningTourPanel(
          stage: OnboardingStage.fetchingRelease,
          sourceCommit: 'abcdef1234567',
          sourceService: GithubProvisioningSourceService(client: client),
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
    expect(client.requestedPaths, hasLength(3));
  });
}
