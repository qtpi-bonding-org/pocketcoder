// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:pocketcoder_flutter/design_system/storybook/agent_config_view.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_agent_config_view_stories;
import 'package:pocketcoder_flutter/design_system/storybook/config_picker.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_config_picker_stories;
import 'package:pocketcoder_flutter/design_system/storybook/mode_switcher.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_mode_switcher_stories;
import 'package:pocketcoder_flutter/design_system/storybook/notification_and_system.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_notification_and_system_stories;
import 'package:pocketcoder_flutter/design_system/storybook/plan_panel.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_plan_panel_stories;
import 'package:pocketcoder_flutter/design_system/storybook/poco_value_widget.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_poco_value_widget_stories;
import 'package:pocketcoder_flutter/design_system/storybook/pro_paywall.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_pro_paywall_stories;
import 'package:pocketcoder_flutter/design_system/storybook/provider_widgets.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_provider_widgets_stories;
import 'package:pocketcoder_flutter/design_system/storybook/settings_view.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_settings_view_stories;
import 'package:pocketcoder_flutter/design_system/storybook/skills_view.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_skills_view_stories;
import 'package:pocketcoder_flutter/design_system/storybook/terminal_conversation.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_terminal_conversation_stories;
import 'package:pocketcoder_flutter/design_system/storybook/tool_permissions_view.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_tool_permissions_view_stories;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookFolder(
    name: 'presentation',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'agent',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'widgets',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'ConfigPicker',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'boolean and select options',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_config_picker_stories
                            .configPickerPopulated,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'empty config',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_config_picker_stories
                            .configPickerEmpty,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'ModeSwitcher',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'no modes',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_mode_switcher_stories
                            .modeSwitcherEmpty,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'selectable modes',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_mode_switcher_stories
                            .modeSwitcherPopulated,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'PlanPanel',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'active and completed tasks',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_plan_panel_stories
                            .planPanelPopulated,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'no plan',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_plan_panel_stories
                            .planPanelEmpty,
                  ),
                ],
              ),
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'agent_config',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'widgets',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'AgentConfigView',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'empty registry',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_agent_config_view_stories
                            .agentConfigEmpty,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'loading registry',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_agent_config_view_stories
                            .agentConfigLoading,
                  ),
                ],
              )
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'billing',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ProPaywallView',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: '7-day trial',
                builder:
                    _pocketcoder_flutter_design_system_storybook_pro_paywall_stories
                        .proPaywallTrial,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'active',
                builder:
                    _pocketcoder_flutter_design_system_storybook_pro_paywall_stories
                        .proPaywallActive,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'loading',
                builder:
                    _pocketcoder_flutter_design_system_storybook_pro_paywall_stories
                        .proPaywallLoading,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'store unavailable',
                builder:
                    _pocketcoder_flutter_design_system_storybook_pro_paywall_stories
                        .proPaywallUnavailable,
              ),
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'chat',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'widgets',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'ChatListView',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'sample chats',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_notification_and_system_stories
                            .chatListSample,
                  )
                ],
              )
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'core',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'widgets',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'PocoValueWidget',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'error message',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_poco_value_widget_stories
                            .pocoValueWidgetError,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'happy message',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_poco_value_widget_stories
                            .pocoValueWidgetHappy,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'TerminalConversationFrame',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'live message frame',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_terminal_conversation_stories
                            .terminalLiveFrame,
                  )
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'TerminalConversationTurn',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'prepared Poco turn',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_terminal_conversation_stories
                            .terminalPocoTurn,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'prepared user turn',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_terminal_conversation_stories
                            .terminalUserTurn,
                  ),
                ],
              ),
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'notifications',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'NotificationSettingsView',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'loaded toggles',
                builder:
                    _pocketcoder_flutter_design_system_storybook_notification_and_system_stories
                        .notificationSettingsLoaded,
              )
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'provider',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'widgets',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'ProviderHarnessPicker',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'provider picker with choices',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_provider_widgets_stories
                            .providerPickerChoices,
                  )
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'ProviderKeyEditorDialog',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'no provider selected',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_provider_widgets_stories
                            .providerEditorEmpty,
                  )
                ],
              ),
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'settings',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'widgets',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'SettingsView',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'no pending changes',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_settings_view_stories
                            .settingsDefault,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'pending MCP badge',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_settings_view_stories
                            .settingsPendingMcp,
                  ),
                ],
              )
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'skills',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'widgets',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'SkillsView',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'empty state',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_skills_view_stories
                            .skillsEmpty,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'global and project skills',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_skills_view_stories
                            .skillsPopulated,
                  ),
                  _widgetbook.WidgetbookUseCase(
                    name: 'loading',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_skills_view_stories
                            .skillsLoading,
                  ),
                ],
              )
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'system',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'SystemChecksView',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'empty checks',
                builder:
                    _pocketcoder_flutter_design_system_storybook_notification_and_system_stories
                        .systemChecksEmpty,
              )
            ],
          )
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'tool_permissions',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'ToolPermissionsView',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'no rules',
                builder:
                    _pocketcoder_flutter_design_system_storybook_tool_permissions_view_stories
                        .toolPermissionsViewEmpty,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'populated rules',
                builder:
                    _pocketcoder_flutter_design_system_storybook_tool_permissions_view_stories
                        .toolPermissionsViewPopulated,
              ),
            ],
          )
        ],
      ),
    ],
  )
];
