import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/user.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/application/users/user_management_state.dart';
import 'package:pocketcoder_flutter/presentation/users/widgets/user_management_view.dart';

const _user = User(id: 'u1', email: 'teammate@example.com', role: UserRole.user);

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('lists non-admin users with delete/reset actions',
      (tester) async {
    await tester.pumpWidget(_wrap(UserManagementView(
      state: const UserManagementState(
        status: UiFlowStatus.success,
        users: [_user],
      ),
      onCreate: (_) async => 'Ab2cdEfg',
      onResetPassword: (_) async => 'Xy9zAbCd',
      onDelete: (_) {},
    )));

    expect(find.text('teammate@example.com'), findsOneWidget);
  });

  testWidgets('add-user dialog reveals the returned password once',
      (tester) async {
    await tester.pumpWidget(_wrap(UserManagementView(
      state: const UserManagementState(status: UiFlowStatus.success),
      onCreate: (_) async => 'Ab2cdEfg',
      onResetPassword: (_) async => 'Xy9zAbCd',
      onDelete: (_) {},
    )));

    await tester.tap(find.text('<add user>'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new@example.com');
    await tester.tap(find.text('<add>'));
    await tester.pumpAndSettle();

    expect(find.text('Ab2cdEfg'), findsOneWidget);
  });
}
