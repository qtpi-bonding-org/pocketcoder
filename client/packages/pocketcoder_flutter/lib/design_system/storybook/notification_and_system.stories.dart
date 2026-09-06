import 'package:flutter/material.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/application/notifications/notification_rule_state.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/notifications/notification_settings_screen.dart';
import 'package:pocketcoder_flutter/presentation/system/widgets/system_checks_view.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_view.dart';

Widget _localized(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

@wb.UseCase(name: 'loaded toggles', type: NotificationSettingsView)
Widget notificationSettingsLoaded(BuildContext context) => _localized(
      NotificationSettingsView(
        state: NotificationRuleState(status: UiFlowStatus.success, rules: {
          'chat_reply': true,
          'schedule': false,
          'task_complete': true,
          'task_error': false,
        }),
        onChanged: (_, __) async {},
        onEnableDevice: () async => true,
        onConfigureSelfHostedPush: () {},
      ),
    );

@wb.UseCase(name: 'empty checks', type: SystemChecksView)
Widget systemChecksEmpty(BuildContext context) => _localized(
      SystemChecksView(
        state: const HealthState(),
        onRefresh: () {},
      ),
    );

@wb.UseCase(name: 'sample chats', type: ChatListView)
Widget chatListSample(BuildContext context) => _localized(
      ChatListView(
        state: ChatListState(
          status: UiFlowStatus.success,
          chats: [
            Chat(
              id: 'chat-1',
              title: 'Deployment review',
              user: 'pocketcoder-admin',
              preview: 'The server is ready for review.',
              lastActive: DateTime(2026, 8, 9, 10, 30),
            ),
            Chat(
              id: 'chat-2',
              title: 'MCP configuration',
              user: 'pocketcoder-admin',
              preview: 'Waiting for approval.',
              lastActive: DateTime(2026, 8, 8, 16),
            ),
          ],
        ),
        onNewChat: () {},
        onOpen: (_) {},
        onArchive: (_) {},
        onDelete: (_) {},
      ),
    );
