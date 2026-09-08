import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_modes_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/permission_modes/widgets/permission_modes_view.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

PermissionMode _mode(String id, String name, {bool system = false}) =>
    PermissionMode(
      id: id,
      name: name,
      description: '$name description',
      baseSessionMode: PermissionModeBaseSessionMode.approve,
      isSystem: system,
    );

void main() {
  testWidgets('renders the mode list and opens a mode row', (tester) async {
    PermissionMode? opened;
    final mode = _mode('read', 'read');
    await tester.pumpWidget(_app(PermissionModesView(
      state: PermissionModesState(
        status: UiFlowStatus.success,
        modes: [mode, _mode('custom', 'custom')],
      ),
      onOpenMode: (value) => opened = value,
      onDuplicateMode: (_, __) async {},
      onDeleteMode: (_) async {},
    )));

    expect(find.byType(DetailRow), findsNWidgets(2));
    expect(find.text('read'), findsOneWidget);
    await tester.tap(find.text('read'));
    expect(opened, mode);
  });

  testWidgets('shows a loading spinner', (tester) async {
    await tester.pumpWidget(_app(PermissionModesView(
      state: const PermissionModesState(status: UiFlowStatus.loading),
      onOpenMode: (_) {},
      onDuplicateMode: (_, __) async {},
      onDeleteMode: (_) async {},
    )));

    expect(find.byType(TerminalSpinner), findsOneWidget);
  });

  testWidgets('shows the failure message', (tester) async {
    await tester.pumpWidget(_app(PermissionModesView(
      state: const PermissionModesState(
        status: UiFlowStatus.failure,
        error: 'unable to load modes',
      ),
      onOpenMode: (_) {},
      onDuplicateMode: (_, __) async {},
      onDeleteMode: (_) async {},
    )));

    expect(find.text('error.generic'), findsOneWidget);
  });
}
