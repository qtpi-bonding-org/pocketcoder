import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/mcp/widgets/mcp_management_view.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

McpManagementView _view(McpServer server) => McpManagementView(
      servers: [server],
      oauthProviders: Future.value(const <McpOAuthProvider>[]),
      hasPendingDelivery: (_) => false,
      onAuthorize: (_, __) {},
      onDeny: (_) {},
      onConnectOAuth: (_) {},
      onRetryOAuth: (_) {},
      onCreateServer: ({
        required String name,
        String? image,
        String? oauthProvider,
        String? oauthTokenEnvVar,
      }) {},
    );

void main() {
  testWidgets('pending DENY is warning-colored, not danger red', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _view(
          const McpServer(
            id: 'pending-1',
            name: 'Pending server',
            status: McpServerStatus.pending,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deny = tester
        .widgetList<BiosActionButton>(find.byType(BiosActionButton))
        .firstWhere((button) => button.action.label == 'DENY');
    expect(deny.action.kind, isNot(ActionKind.destructive));
    expect(deny.action.kind, ActionKind.refusal);
  });

  testWidgets('approved REVOKE remains danger red', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _view(
          const McpServer(
            id: 'approved-1',
            name: 'Approved server',
            status: McpServerStatus.approved,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final revoke = tester
        .widgetList<BiosActionButton>(find.byType(BiosActionButton))
        .firstWhere((button) => button.action.label == 'REVOKE');
    expect(revoke.action.kind, ActionKind.destructive);
  });

  testWidgets('renders a pending server as a DetailRow with a BiosActionStrip',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _view(
          const McpServer(
            id: 'pending-2',
            name: 'filesystem',
            status: McpServerStatus.pending,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DetailRow), findsWidgets);
    expect(find.byType(BiosActionStrip), findsOneWidget);
    expect(find.text('filesystem'), findsOneWidget);
  });
}
