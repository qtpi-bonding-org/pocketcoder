import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/settings/widgets/settings_view.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

@wb.UseCase(name: 'no pending changes', type: SettingsView)
Widget settingsDefault(BuildContext context) => _app(SettingsView(
  hasPendingMcp: false, onNavigate: (_) {}, onLogout: () {}, onFactoryReset: () {},
));

@wb.UseCase(name: 'pending MCP badge', type: SettingsView)
Widget settingsPendingMcp(BuildContext context) => _app(SettingsView(
  hasPendingMcp: true, onNavigate: (_) {}, onLogout: () {}, onFactoryReset: () {},
));
