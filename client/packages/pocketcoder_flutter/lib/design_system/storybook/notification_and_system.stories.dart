import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/application/notifications/notification_rule_state.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/notifications/notification_settings_screen.dart';
import 'package:pocketcoder_flutter/presentation/system/system_checks_screen.dart';

Widget _localized(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

@wb.UseCase(name: 'loaded toggles', type: NotificationSettingsView)
Widget notificationSettingsLoaded(BuildContext context) => _localized(
      NotificationSettingsView(
        state: const NotificationRuleState.loaded({
          'chat_reply': true,
          'schedule': false,
          'task_complete': true,
          'task_error': false,
        }),
        onChanged: (_, __) async {},
      ),
    );

@wb.UseCase(name: 'empty checks', type: SystemChecksView)
Widget systemChecksEmpty(BuildContext context) => _localized(
      SystemChecksView(
        state: const HealthState(),
        onRefresh: () {},
      ),
    );
