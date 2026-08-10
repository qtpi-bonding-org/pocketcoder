import 'dart:convert';
import 'dart:typed_data';

import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart' as ag_ui;
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/application/billing/billing_state.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/application/notifications/notification_rule_state.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_state.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deploy_option_service.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/models/schedule.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/agent_config_view.dart';
import 'package:pocketcoder_flutter/presentation/billing/permission_relay_screen.dart';
import 'package:pocketcoder_flutter/presentation/boot/boot_view.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_view.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/terminal_command_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_view.dart';
import 'package:pocketcoder_flutter/presentation/chat/elicitation_card.dart';
import 'package:pocketcoder_flutter/presentation/chat/permission_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_picker_screen.dart';
import 'package:pocketcoder_flutter/presentation/errors/error_inbox_screen.dart';
import 'package:pocketcoder_flutter/presentation/files/file_browser_screen.dart';
import 'package:pocketcoder_flutter/presentation/files/file_viewer_screen.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/harness_auth_view.dart';
import 'package:pocketcoder_flutter/presentation/mcp/widgets/mcp_management_view.dart';
import 'package:pocketcoder_flutter/presentation/monitor/monitor_screen.dart';
import 'package:pocketcoder_flutter/presentation/notifications/notification_settings_screen.dart';
import 'package:pocketcoder_flutter/presentation/observability/agent_observability_screen.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/deploy_credentials_view.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/harness_authorization_view.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/harness_choice_view.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_login_view.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_view.dart';
import 'package:pocketcoder_flutter/presentation/provider/adapters/provider_adapter.dart';
import 'package:pocketcoder_flutter/presentation/scheduler/scheduler_screen.dart';
import 'package:pocketcoder_flutter/presentation/settings/widgets/settings_view.dart';
import 'package:pocketcoder_flutter/presentation/skills/widgets/skills_view.dart';
import 'package:pocketcoder_flutter/presentation/system/system_checks_screen.dart';
import 'package:pocketcoder_flutter/presentation/tool_permissions/tool_permissions_screen.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/domain/deployment/harness_catalog.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';
import 'package:pocketcoder_pro/domain/server_update/server_update_result.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_credentials.dart';
import 'package:pocketcoder_pro/presentation/auth/widgets/auth_view.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/config_view.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/details_view.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/progress_view.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/provisioning_lesson_card.dart';
import 'package:pocketcoder_pro/presentation/server_update/widgets/update_server_view.dart';
import 'package:widgetbook/widgetbook.dart';

typedef _StoryBuilder = Widget Function();

Widget _localizedApp(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

WidgetbookComponent _screen(
  String name,
  Map<String, _StoryBuilder> stories,
) =>
    WidgetbookComponent(
      name: name,
      useCases: [
        for (final story in stories.entries)
          WidgetbookUseCase(
            name: story.key,
            builder: (_) => _localizedApp(story.value()),
          ),
      ],
    );

final screenDirectories = <WidgetbookNode>[
  WidgetbookFolder(
      name: 'Startup and onboarding', children: _onboardingScreens),
  WidgetbookFolder(name: 'Configuration', children: _configurationScreens),
  WidgetbookFolder(name: 'Operations', children: _operationsScreens),
  WidgetbookFolder(name: 'Chats and files', children: _chatAndFileScreens),
  WidgetbookFolder(name: 'Pro', children: _proScreens),
];

final _onboardingScreens = <WidgetbookNode>[
  _screen('BootScreen', {
    'boot log and assistant': () => BootView(
          logs: const [
            '[sys] POCKETCODER BIOS 1.0',
            '[sys] VERIFYING LOCAL STORAGE... OK',
            '[net] CHECKING POCKETBASE... OK',
            '[net] RESTORING SESSION... OK',
            '[sys] STARTING USER INTERFACE...',
          ],
          logsDimmed: true,
          pocoVisible: true,
          pocoState: const PocoState(
            message: 'SYSTEMS NOMINAL. WELCOME BACK.',
            sequence: PocoExpressions.happy,
          ),
          scrollController: ScrollController(),
        ),
  }),
  _screen('OnboardingScreen', {
    'connect or deploy': () => OnboardingView(
          pocoState: const PocoState(
            message: 'HOW WOULD YOU LIKE TO START?',
            sequence: PocoExpressions.happy,
          ),
          onLogin: () {},
          onDeploy: () {},
        ),
  }),
  _screen('OnboardingLoginScreen', {
    'populated': () => OnboardingLoginView(
          initialUrl: 'https://pocketcoder.example.test',
          initialEmail: 'admin@example.test',
          initialPassword: 'demo-password',
          status: UiFlowStatus.idle,
          pocoMessage: 'ENTER THE CREDENTIALS FOR YOUR SERVER.',
          pocoSequence: PocoExpressions.scanning,
          pocoHistory: const [],
          onBack: () {},
          onDeploy: () {},
          onLogin: (_, __, ___) async {},
        ),
    'loading': () => OnboardingLoginView(
          initialUrl: 'https://pocketcoder.example.test',
          initialEmail: 'admin@example.test',
          initialPassword: 'demo-password',
          status: UiFlowStatus.loading,
          pocoMessage: 'AUTHENTICATING WITH YOUR SERVER...',
          pocoSequence: PocoExpressions.scanning,
          pocoHistory: const [],
          onBack: () {},
          onDeploy: () {},
          onLogin: (_, __, ___) async {},
        ),
  }),
  _screen('OnboardingDeployCredentialsScreen', {
    'empty form': () => DeployCredentialsView(
          email: '',
          password: '',
          onEmailChanged: (_) {},
          onPasswordChanged: (_) {},
          onContinue: () {},
        ),
    'populated form': () => DeployCredentialsView(
          email: 'admin@example.test',
          password: 'demo-password',
          onEmailChanged: (_) {},
          onPasswordChanged: (_) {},
          onContinue: () {},
        ),
  }),
  _screen('HarnessChoiceScreen', {
    'available harnesses': () => HarnessChoiceView(
          status: UiFlowStatus.success,
          harnesses: _harnesses,
          error: null,
          onSelected: (_) {},
        ),
    'loading': () => HarnessChoiceView(
          status: UiFlowStatus.loading,
          harnesses: const [],
          error: null,
          onSelected: (_) {},
        ),
  }),
  _screen('HarnessAuthorizationScreen', {
    'device challenge': () => HarnessAuthorizationView(
          harnessId: 'codex',
          provider: 'codex',
          isLoading: false,
          harnessExists: true,
          status: _connectingStatus,
          isBusy: false,
          onPoll: () async {},
          onSubmit: (_) async {},
          onStartLogin: () async {},
          onOpenChallenge: (_) {},
        ),
    'connected': () => HarnessAuthorizationView(
          harnessId: 'codex',
          provider: 'codex',
          isLoading: false,
          harnessExists: true,
          status: _connectedStatus,
          isBusy: false,
          onPoll: () async {},
          onSubmit: (_) async {},
          onStartLogin: () async {},
          onOpenChallenge: (_) {},
        ),
  }),
  _screen('HarnessAuthScreen', {
    'connected and disconnected': () => HarnessAuthScreenView(
          onboarding: false,
          harnesses: _harnesses,
          providerKeys: _providerKeys,
          statuses: const {
            'claude': HarnessAuthStatus(
              harness: 'claude',
              scopeKind: 'user',
              scopeId: 'demo-user',
              bindingId: 'binding-1',
              credentialMode: 'account',
              status: 'connected',
            ),
            'codex': _connectingStatus,
          },
          error: null,
          isLoading: false,
          isHarnessBusy: (_) => false,
          onStartAccount: (_) {},
          onStartApiKey: (_) async {},
          onStartNone: (_) {},
          onPoll: (_) {},
          onSubmit: (_, __) async {},
          onCancel: (_) {},
          onDisconnect: (_) {},
          onRefresh: (_) {},
        ),
  }),
];

final _configurationScreens = <WidgetbookNode>[
  _screen('DeployPickerScreen', {
    'provider options': () => DeployPickerView(
          options: const [
            DeployOption(
              id: 'linode',
              name: 'Linode',
              description: 'Managed in-app cloud provisioning',
              routePath: '/auth',
              requiresPurchase: true,
            ),
            DeployOption(
              id: 'hetzner',
              name: 'Hetzner',
              description: 'Open the self-hosted deployment guide',
              url: 'https://example.test',
            ),
          ],
          onSelected: (_) async {},
        ),
  }),
  _screen('ProviderScreen', {
    'configured providers': () => ProviderView(
          state: ProviderState(
            status: UiFlowStatus.success,
            harnesses: _harnesses,
            models: const [
              Model(
                id: 'model-1',
                name: 'gpt-5',
                displayName: 'GPT-5',
                provider: 'openai',
              ),
            ],
            harnessModels: const [
              HarnessModel(
                id: 'hm-1',
                harness: 'codex',
                model: 'model-1',
                harnessModelId: 'codex::gpt-5',
                isDefault: true,
              ),
            ],
            providerKeys: _providerKeys,
          ),
          onDelete: (_) async {},
          onSave: (_) async {},
        ),
    'loading': () => ProviderView(
          state: const ProviderState(status: UiFlowStatus.loading),
          onDelete: (_) async {},
          onSave: (_) async {},
        ),
  }),
  _screen('AgentConfigScreen', {
    'configured agents': () => AgentConfigView(
          state: const AgentConfigState(
            status: UiFlowStatus.success,
            configs: [
              PocoConfig(
                id: 'config-1',
                name: 'PocketCoder Default',
                harnessModel: 'codex::gpt-5',
                isDefault: true,
              ),
              PocoConfig(
                id: 'config-2',
                name: 'Review Mode',
                harnessModel: 'claude-code::sonnet',
              ),
            ],
          ),
          providerState: ProviderState(harnesses: _harnesses),
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
    'loading': () => AgentConfigView(
          state: const AgentConfigState(status: UiFlowStatus.loading),
          providerState: const ProviderState(),
          onSave: (_) async {},
          onDelete: (_) async {},
        ),
  }),
  _screen('SettingsScreen', {
    'pending MCP approval': () => SettingsView(
          hasPendingMcp: true,
          onNavigate: (_) {},
          onLogout: () {},
        ),
  }),
  _screen('SkillsScreen', {
    'global and project skills': () => SkillsView(
          data: const SkillsViewData(skills: [
            Skill(
              name: 'deploy',
              description: 'Deploy the current project.',
              content: 'run deploy',
              path: 'global/deploy.md',
              global: true,
            ),
            Skill(
              name: 'review',
              description: 'Review changes before merging.',
              content: 'review diff',
              path: 'project/review.md',
              global: false,
            ),
          ]),
          onAdd: () {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
    'error': () => SkillsView(
          data: const SkillsViewData(error: 'Skill registry unavailable'),
          onAdd: () {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
  }),
  _screen('McpManagementScreen', {
    'pending and active servers': () => McpManagementView(
          servers: _mcpServers,
          oauthProviders: Future.value(const []),
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
        ),
  }),
  _screen('ToolPermissionsScreen', {
    'populated rules': () => ToolPermissionsView(
          state: const ToolPermissionsState.loaded([
            ToolPermission(
              id: 'rule-1',
              tool: 'shell',
              pattern: 'rm *',
              action: ToolPermissionAction.ask,
              active: true,
            ),
            ToolPermission(
              id: 'rule-2',
              tool: 'read',
              pattern: '*',
              action: ToolPermissionAction.allow,
              active: true,
            ),
          ]),
          onSetActive: (_, __) async {},
          onUpdateAction: (_, __) async {},
          onCreateRule: (_, __) async {},
        ),
    'error': () => ToolPermissionsView(
          state: const ToolPermissionsState.error('Rules could not be loaded'),
          onSetActive: (_, __) async {},
          onUpdateAction: (_, __) async {},
          onCreateRule: (_, __) async {},
        ),
  }),
  _screen('SystemChecksScreen', {
    'healthy and degraded': () => SystemChecksView(
          state: const HealthState(
            status: UiFlowStatus.success,
            checks: [
              Healthcheck(
                id: 'pocketbase',
                name: 'PocketBase',
                status: HealthcheckStatus.ready,
              ),
              Healthcheck(
                id: 'goose',
                name: 'Goose ACP',
                status: HealthcheckStatus.degraded,
              ),
            ],
          ),
          onRefresh: () {},
        ),
  }),
  _screen('NotificationSettingsScreen', {
    'loaded toggles': () => NotificationSettingsView(
          state: const NotificationRuleState.loaded({
            'chat_reply': true,
            'schedule': false,
            'task_complete': true,
            'task_error': true,
          }),
          onChanged: (_, __) async {},
        ),
    'error': () => NotificationSettingsView(
          state: const NotificationRuleState.error(
            'Notification rules unavailable',
          ),
          onChanged: (_, __) async {},
        ),
  }),
  _screen('ErrorInboxScreen', {
    'captured error': () => ErrorInboxScreen(
          errors: [_errorEntry],
          onCopyAll: () {},
          onClearAll: () {},
          onCopy: (_) async {},
          onDelete: (_) async {},
        ),
    'empty': () => ErrorInboxScreen(
          errors: const [],
          onCopyAll: () {},
          onClearAll: () {},
          onCopy: (_) async {},
          onDelete: (_) async {},
        ),
  }),
];

final _operationsScreens = <WidgetbookNode>[
  _screen('SchedulerScreen', {
    'scheduled and running': () => SchedulerView(
          state: const SchedulerState.loaded([
            Schedule(
              id: 'schedule-1',
              displayName: 'Nightly workspace review',
              cron: '0 2 * * *',
              paused: false,
              currentlyRunning: true,
            ),
            Schedule(
              id: 'schedule-2',
              displayName: 'Weekly dependency audit',
              cron: '0 9 * * MON',
              paused: true,
              currentlyRunning: false,
            ),
          ]),
          onPause: (_) {},
          onUnpause: (_) {},
          onRunNow: (_) {},
          onDelete: (_) {},
          onRename: (
              {required String id, required String displayName}) async {},
          onUpdateCron: ({required String id, required String cron}) async {},
          onCreate: ({
            required String displayName,
            required String cron,
            required String prompt,
          }) async {},
        ),
    'empty': () => SchedulerView(
          state: const SchedulerState.loaded([]),
          onPause: (_) {},
          onUnpause: (_) {},
          onRunNow: (_) {},
          onDelete: (_) {},
          onRename: (
              {required String id, required String displayName}) async {},
          onUpdateCron: ({required String id, required String cron}) async {},
          onCreate: ({
            required String displayName,
            required String cron,
            required String prompt,
          }) async {},
        ),
  }),
  _screen('AgentObservabilityScreen', {
    'live container logs': () => AgentObservabilityView(
          state: _observabilityState,
          onRefresh: () {},
          onSelectContainer: (_) {},
        ),
  }),
  _screen('MonitorScreen', {
    'system telemetry': () => MonitorView(
          state: _observabilityState,
          onRefresh: () {},
        ),
    'error': () => MonitorView(
          state: const ObservabilityState(
            status: UiFlowStatus.failure,
            error: 'Telemetry endpoint unavailable',
          ),
          onRefresh: () {},
        ),
  }),
  _screen('PermissionRelayScreen', {
    'subscription options': () => PermissionRelayView(
          state: const BillingState(
            status: UiFlowStatus.success,
            packages: [
              BillingPackage(
                identifier: 'permission_relay_monthly',
                title: 'Permission Relay',
                description: 'Approve remote tool requests from this device.',
                priceString: r'$4.99 / month',
              ),
            ],
          ),
          onRestore: () {},
          onPurchase: (_) async {},
          onConfigure: () {},
        ),
    'active': () => PermissionRelayView(
          state: const BillingState(
            status: UiFlowStatus.success,
            isPro: true,
          ),
          onRestore: () {},
          onPurchase: (_) async {},
          onConfigure: () {},
        ),
  }),
];

final _chatAndFileScreens = <WidgetbookNode>[
  _screen('ChatListScreen', {
    'populated': () => ChatListView(
          state: ChatListState(
            status: UiFlowStatus.success,
            chats: [
              Chat(
                id: 'chat-1',
                title: 'Deployment review',
                user: 'demo-user',
                preview: 'The server is ready for review.',
                lastActive: DateTime(2026, 8, 9, 10, 30),
              ),
              Chat(
                id: 'chat-2',
                title: 'MCP configuration',
                user: 'demo-user',
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
    'loading empty list': () => ChatListView(
          state: const ChatListState(status: UiFlowStatus.loading),
          onNewChat: () {},
          onOpen: (_) {},
          onArchive: (_) {},
          onDelete: (_) {},
        ),
  }),
  _screen('ChatScreen', {
    'conversation': () => ChatView(
          chatId: 'chat-1',
          conversation: const ag_ui.Conversation(timeline: [
            ag_ui.TimelineItem.text(
              id: 'message-1',
              kind: ag_ui.ChatMessageKind.text,
              role: 'user',
              text: 'Review the deployment configuration.',
              order: ag_ui.OrderKey(1),
            ),
            ag_ui.TimelineItem.text(
              id: 'message-2',
              kind: ag_ui.ChatMessageKind.text,
              role: 'assistant',
              text: 'The deployment is healthy and ready for verification.',
              order: ag_ui.OrderKey(2),
            ),
          ]),
          title: 'Deployment review',
          isLoading: false,
          isRunning: true,
          modes: const {'currentModeId': 'code', 'availableModes': []},
          config: const {},
          onOpen: (_) {},
          onSendPrompt: (_) {},
          onCancel: () {},
          onSelectMode: (_) {},
          onSetOption: (_) {},
          onPermissionOptionSelected: (
            _, {
            String? optionId,
            bool cancelled = false,
          }) {},
          onElicitationRespond: (_, __) {},
          onFiles: () {},
        ),
    'thinking': () => ChatView(
          chatId: 'chat-1',
          conversation: const ag_ui.Conversation(timeline: [
            ag_ui.TimelineItem.text(
              id: 'message-1',
              kind: ag_ui.ChatMessageKind.text,
              role: 'user',
              text: 'Can you check the deployment logs?',
              order: ag_ui.OrderKey(1),
            ),
            ag_ui.TimelineItem.text(
              id: 'reasoning-1',
              kind: ag_ui.ChatMessageKind.reasoning,
              role: 'assistant',
              text:
                  'Reviewing the latest deployment events and service health.',
              order: ag_ui.OrderKey(2),
            ),
          ]),
          title: 'Deployment review',
          isLoading: true,
          isRunning: true,
          modes: const {'currentModeId': 'code', 'availableModes': []},
          config: const {},
          onOpen: (_) {},
          onSendPrompt: (_) {},
          onCancel: () {},
          onSelectMode: (_) {},
          onSetOption: (_) {},
          onPermissionOptionSelected: (
            _, {
            String? optionId,
            bool cancelled = false,
          }) {},
          onElicitationRespond: (_, __) {},
          onFiles: () {},
        ),
    'streaming response': () => ChatView(
          chatId: 'chat-1',
          conversation: const ag_ui.Conversation(timeline: [
            ag_ui.TimelineItem.text(
              id: 'message-1',
              kind: ag_ui.ChatMessageKind.text,
              role: 'user',
              text: 'Summarize the deployment status.',
              order: ag_ui.OrderKey(1),
            ),
            ag_ui.TimelineItem.textStream(
              id: 'message-2',
              role: 'assistant',
              text: 'The deployment is currently healthy and',
              order: ag_ui.OrderKey(2),
            ),
          ]),
          title: 'Deployment review',
          isLoading: true,
          isRunning: true,
          modes: const {'currentModeId': 'code', 'availableModes': []},
          config: const {},
          onOpen: (_) {},
          onSendPrompt: (_) {},
          onCancel: () {},
          onSelectMode: (_) {},
          onSetOption: (_) {},
          onPermissionOptionSelected: (
            _, {
            String? optionId,
            bool cancelled = false,
          }) {},
          onElicitationRespond: (_, __) {},
          onFiles: () {},
        ),
    'empty': () => ChatView(
          chatId: 'new',
          conversation: const ag_ui.Conversation(),
          title: 'New chat',
          isLoading: false,
          isRunning: false,
          modes: const {'currentModeId': 'code', 'availableModes': []},
          config: const {},
          onOpen: (_) {},
          onSendPrompt: (_) {},
          onCancel: () {},
          onSelectMode: (_) {},
          onSetOption: (_) {},
          onPermissionOptionSelected: (
            _, {
            String? optionId,
            bool cancelled = false,
          }) {},
          onElicitationRespond: (_, __) {},
          onFiles: () {},
        ),
  }),
  _screen('TerminalCommandCard', {
    'completed with collapsed output': () => _localizedApp(
          Scaffold(
            body: Padding(
              padding: EdgeInsets.all(AppSizes.space * 2),
              child: Builder(
                builder: (context) => TerminalCommandCard(
                  command: 'flutter test test/presentation/chat',
                  status: TerminalStatus.success,
                  outputLabel: context.l10n.chatCommandOutput,
                  output: 'All tests passed!',
                ),
              ),
            ),
          ),
        ),
    'running': () => _localizedApp(
          Scaffold(
            body: Padding(
              padding: EdgeInsets.all(AppSizes.space * 2),
              child: Builder(
                builder: (context) => TerminalCommandCard(
                  command: 'flutter test test/presentation/chat',
                  status: TerminalStatus.running,
                  outputLabel: context.l10n.chatCommandOutput,
                ),
              ),
            ),
          ),
        ),
    'failed': () => _localizedApp(
          Scaffold(
            body: Padding(
              padding: EdgeInsets.all(AppSizes.space * 2),
              child: Builder(
                builder: (context) => TerminalCommandCard(
                  command: 'flutter test test/presentation/chat',
                  status: TerminalStatus.failure,
                  outputLabel: context.l10n.chatCommandOutput,
                  output: 'Test process exited with code 1.',
                ),
              ),
            ),
          ),
        ),
  }),
  _screen('PermissionCard', {
    'pending approval': () => _localizedApp(
          Scaffold(
            body: PermissionCard(
              item: const ag_ui.PermissionRequestTimelineItem(
                requestId: 'permission-1',
                toolTitle: 'run shell command',
                options: [
                  ag_ui.PermissionOption(
                    optionId: 'allow-once',
                    label: 'Allow once',
                    kind: 'allow_once',
                  ),
                ],
                order: ag_ui.OrderKey(1),
              ),
              onSelect: (_, {optionId, cancelled = false}) {},
            ),
          ),
        ),
  }),
  _screen('ElicitationCard', {
    'form request': () => _localizedApp(
          Scaffold(
            body: ElicitationCard(
              item: const ag_ui.ElicitationRequestTimelineItem(
                requestId: 'elicitation-1',
                message: 'Tell Poco how to configure the service.',
                mode: 'form',
                schema: {
                  'type': 'object',
                  'properties': {
                    'environment': {
                      'type': 'string',
                      'title': 'Environment',
                    },
                  },
                },
                order: ag_ui.OrderKey(1),
              ),
              onRespond: (_, __) {},
            ),
          ),
        ),
  }),
  _screen('FileBrowserScreen', {
    'workspace files': () => FileBrowserView(
          state: const FileBrowserState(
            status: UiFlowStatus.success,
            path: 'client/lib',
            entries: [
              FileEntry(
                name: 'presentation',
                isDir: true,
                size: 0,
                modTime: '2026-08-09T10:00:00Z',
              ),
              FileEntry(
                name: 'main.dart',
                isDir: false,
                size: 2048,
                modTime: '2026-08-09T10:05:00Z',
              ),
            ],
          ),
          onOpenFile: (_, __) {},
          onNavigateInto: (_) {},
        ),
    'empty': () => FileBrowserView(
          state: const FileBrowserState(status: UiFlowStatus.success),
          onOpenFile: (_, __) {},
          onNavigateInto: (_) {},
        ),
  }),
  _screen('FileViewerScreen', {
    'source file': () => FileViewerView(
          path: 'client/lib/main.dart',
          loading: false,
          bytes: Uint8List.fromList(
            utf8.encode(
              "import 'package:flutter/material.dart';\n\n"
              'void main() => runApp(const PocketCoderApp());\n',
            ),
          ),
          error: null,
        ),
    'error': () => const FileViewerView(
          path: 'client/lib/missing.dart',
          loading: false,
          bytes: null,
          error: 'File was not found',
        ),
  }),
];

final _proScreens = <WidgetbookNode>[
  _screen('AuthScreen', {
    'ready': () => AuthView(
          isLoading: false,
          errorMessage: null,
          onAuthenticate: () {},
          onBack: () {},
        ),
    'error': () => AuthView(
          isLoading: false,
          errorMessage: 'OAuth gateway unavailable',
          onAuthenticate: () {},
          onBack: () {},
        ),
  }),
  _screen('ConfigScreen', {
    'populated and valid': () => ConfigView(
          plans: _plans,
          regions: _regions,
          selectedPlan: 'shared-2',
          selectedRegion: 'us-west',
          isValid: true,
          backend: ProvisionBackendKind.standardLinux,
          distribution: StandardLinuxDistribution.ubuntu,
          harnesses: DeploymentHarnessCatalog.bundled.harnesses,
          selectedHarnesses: const ['goose', 'codex'],
          onPlanSelected: (_) {},
          onRegionSelected: (_) {},
          onBackendSelected: (_) {},
          onDistributionSelected: (_) {},
          onHarnessesSelected: (_) {},
          onDeploy: () {},
        ),
    'loading registry': () => ConfigView(
          plans: null,
          regions: null,
          selectedPlan: null,
          selectedRegion: null,
          isValid: false,
          backend: ProvisionBackendKind.standardLinux,
          distribution: StandardLinuxDistribution.ubuntu,
          harnesses: DeploymentHarnessCatalog.bundled.harnesses,
          selectedHarnesses: const ['goose'],
          onPlanSelected: (_) {},
          onRegionSelected: (_) {},
          onBackendSelected: (_) {},
          onDistributionSelected: (_) {},
          onHarnessesSelected: (_) {},
          onDeploy: () {},
        ),
  }),
  _screen('ProgressScreen', {
    'provisioning': () => ProgressView(
          status: UiFlowStatus.loading,
          deploymentStatus: OnboardingStage.installingHost,
          pollingAttempts: 8,
          serverStatusDocument: ServerStatusDocument(
            schema: 1,
            runId: 'widgetbook-run',
            phase: 'installing_host',
            detail: 'configuring key-only SSH',
            sourceCommit: 'abcdef1234567',
            updatedAt: DateTime.utc(2026, 8, 9, 12, 30),
            raw: const {},
          ),
          provisioningTour: const SizedBox.shrink(),
          instance: null,
          error: null,
          onAbort: () {},
          onRetry: null,
        ),
    'failed': () => ProgressView(
          status: UiFlowStatus.failure,
          deploymentStatus: OnboardingStage.failed,
          pollingAttempts: 20,
          serverStatusDocument: null,
          provisioningTour: const SizedBox.shrink(),
          instance: null,
          error: 'Host provisioning timed out',
          onAbort: () {},
          onRetry: () {},
        ),
  }),
  _screen('ProvisioningLessonCard', {
    'collapsed important code': () => const _ProvisioningLessonCardPreview(),
    'expanded full code': () =>
        const _ProvisioningLessonCardPreview(initiallyExpanded: true),
  }),
  _screen('DetailsScreen', {
    'running instance': () => DetailsView(
          instance: Instance(
            id: 'pc-demo-01',
            label: 'PocketCoder Demo',
            ipAddress: '203.0.113.42',
            status: InstanceStatus.running,
            created: DateTime(2026, 8, 9, 12, 30),
            region: 'Fremont',
            planType: 'Shared 2GB',
            provider: 'linode',
          ),
          credentials: const PocketCoderCredentials(
            instanceId: 'pc-demo-01',
            adminEmail: 'admin@example.test',
            adminPassword: 'demo-password',
          ),
          onRefresh: () {},
          onLogin: () {},
          onUpdate: () {},
          onDismiss: () {},
        ),
  }),
  _screen('UpdateServerScreen', {
    'ready': () => UpdateServerView(
          isLoading: false,
          result: null,
          onUpdate: () {},
          onDismiss: () {},
        ),
    'successful update': () => UpdateServerView(
          isLoading: false,
          result: const ServerUpdateResult(
            exitCode: 0,
            stdout: 'Already up to date.\nServices are healthy.',
            stderr: '',
          ),
          onUpdate: () {},
          onDismiss: () {},
        ),
  }),
];

class _ProvisioningLessonCardPreview extends StatefulWidget {
  const _ProvisioningLessonCardPreview({this.initiallyExpanded = false});

  final bool initiallyExpanded;

  @override
  State<_ProvisioningLessonCardPreview> createState() =>
      _ProvisioningLessonCardPreviewState();
}

class _ProvisioningLessonCardPreviewState
    extends State<_ProvisioningLessonCardPreview> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ProvisioningLessonCard(
              title: 'Installing the NixOS image safely',
              explanation:
                  'We check the destination and the download before allowing the new operating system to take over your VPS.',
              codeBlocks: _installerLessonBlocks,
              lessonNumber: 1,
              lessonCount: 10,
              expanded: _expanded,
              onExpandedChanged: (value) => setState(() => _expanded = value),
              onPrevious: null,
              onNext: () {},
            ),
          ),
        ),
      ),
    );
  }
}

const _installerLessonBlocks = [
  ProvisioningLessonCodeBlock(
    title: 'Installer inputs',
    sourceLabel: 'deploy/nixos/stackscripts/pocketcoder-image-installer.sh:2',
    code: '''# <UDF name="IMAGE_URL" label="NixOS image URL" />
# <UDF name="IMAGE_SHA256" label="Expected sha256 of the gzip" />
# <UDF name="IMAGE_UNCOMPRESSED_BYTES" label="Expected uncompressed size in bytes" />
set -euo pipefail''',
    importantCode: 'set -euo pipefail',
  ),
  ProvisioningLessonCodeBlock(
    title: 'Disk safety check',
    sourceLabel: 'deploy/nixos/stackscripts/pocketcoder-image-installer.sh:10',
    code: '''[ -b /dev/sdb ] || { echo "FATAL: /dev/sdb not found"; exit 1; }
TARGET_BYTES=\$(blockdev --getsize64 /dev/sdb)
[ "\$TARGET_BYTES" -ge "\$IMAGE_UNCOMPRESSED_BYTES" ] || exit 1''',
    importantCode: '''[ -b /dev/sdb ] || exit 1
TARGET_BYTES=\$(blockdev --getsize64 /dev/sdb)
[ "\$TARGET_BYTES" -ge "\$IMAGE_UNCOMPRESSED_BYTES" ] || exit 1''',
  ),
  ProvisioningLessonCodeBlock(
    title: 'Stream the image',
    sourceLabel: 'deploy/nixos/stackscripts/pocketcoder-image-installer.sh:25',
    code: '''curl -fsSL "\$IMAGE_URL" \\
  | tee /tmp/sumpipe \\
  | gunzip \\
  | dd of=/dev/sdb bs=16M conv=fsync status=progress''',
    importantCode: '''curl -fsSL "\$IMAGE_URL" \\
  | gunzip \\
  | dd of=/dev/sdb bs=16M conv=fsync status=progress''',
  ),
  ProvisioningLessonCodeBlock(
    title: 'Verify the checksum',
    sourceLabel: 'deploy/nixos/stackscripts/pocketcoder-image-installer.sh:34',
    code: '''read -r ACTUAL_SHA _ < /tmp/sum
if [ "\$ACTUAL_SHA" = "\$IMAGE_SHA256" ]; then
  echo "Image verified"
fi''',
    importantCode: '[ "\$ACTUAL_SHA" = "\$IMAGE_SHA256" ]',
  ),
];

const _harnesses = [
  Harnesse(
    id: 'claude',
    name: 'Claude Code',
    cliId: 'claude-code',
    acpTransport: HarnesseAcpTransport.websocket,
  ),
  Harnesse(
    id: 'codex',
    name: 'Codex',
    cliId: 'codex',
    acpTransport: HarnesseAcpTransport.websocket,
  ),
];

const _providerKeys = [
  ProviderKey(
    id: 'key-1',
    user: 'demo-user',
    provider: 'codex',
    envVars: {'API_KEY': 'sk-demo-secret'},
  ),
];

const _connectingStatus = HarnessAuthStatus(
  harness: 'codex',
  scopeKind: 'user',
  scopeId: 'demo-user',
  bindingId: '',
  credentialMode: 'account',
  status: 'connecting',
  challenge: HarnessAuthChallenge(
    type: 'device_code',
    text: 'Open the authorization page and enter code ABCD-EFGH.',
    target: 'https://example.test/device',
    details: 'The code expires in 10 minutes.',
  ),
);

const _connectedStatus = HarnessAuthStatus(
  harness: 'codex',
  scopeKind: 'user',
  scopeId: 'demo-user',
  bindingId: 'binding-1',
  credentialMode: 'account',
  status: 'connected',
);

const _mcpServers = [
  McpServer(
    id: 'mcp-1',
    name: 'GitHub tools',
    status: McpServerStatus.pending,
    reason: 'Repository issue and pull request access',
    image: 'ghcr.io/example/github-mcp:latest',
    configSchema: {'GITHUB_TOKEN': 'secret'},
  ),
  McpServer(
    id: 'mcp-2',
    name: 'Local filesystem',
    status: McpServerStatus.approved,
    image: 'ghcr.io/example/filesystem-mcp:latest',
  ),
];

final _errorEntry = ErrorBoxEntry(
  id: 'error-1',
  fingerprint: 'chat-timeout',
  errorData: ErrorEntry(
    source: 'ChatCubit',
    errorType: 'ChatTimeoutException',
    errorCode: 'CHAT_TIMEOUT',
    stackTrace: '#0 ChatCubit.sendPrompt (chat_cubit.dart:120)',
    timestamp: DateTime(2026, 8, 9, 10, 30),
  ),
  occurrenceCount: 2,
  firstOccurred: DateTime(2026, 8, 9, 10),
  lastOccurred: DateTime(2026, 8, 9, 10, 30),
);

const _observabilityState = ObservabilityState(
  status: UiFlowStatus.success,
  currentContainer: 'pocketcoder-goose',
  stats: SystemStats(
    totalMessages: 1842,
    cumulativeCost: r'$12.48',
    cumulativeTokens: 284500,
    backendStatus: 'healthy',
    tokenUsage: [
      TokenUsage(model: 'gpt-5', tokens: 184500),
      TokenUsage(model: 'claude-sonnet', tokens: 100000),
    ],
    tasks: [
      OperationalTask(
        id: 'task-1',
        status: 'running',
        sender: 'planner',
        receiver: 'coder',
        summary: 'Building the combined screen catalog',
        timestamp: '2026-08-09T10:30:00Z',
      ),
    ],
  ),
  logs: [
    'INFO session connected',
    'DEBUG loading workspace context',
    'WARN tool approval pending',
  ],
);

const _plans = [
  InstancePlan(
    id: 'shared-2',
    name: 'Shared 2GB',
    memoryMB: 2048,
    vcpus: 1,
    diskGB: 50,
    monthlyPriceUSD: 12,
    recommended: true,
  ),
  InstancePlan(
    id: 'dedicated-4',
    name: 'Dedicated 4GB',
    memoryMB: 4096,
    vcpus: 2,
    diskGB: 80,
    monthlyPriceUSD: 24,
    recommended: false,
  ),
];

const _regions = [
  Region(id: 'us-west', name: 'us-west', country: 'US', city: 'Fremont'),
  Region(
    id: 'eu-central',
    name: 'eu-central',
    country: 'DE',
    city: 'Frankfurt',
  ),
];
