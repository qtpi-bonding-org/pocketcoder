// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:pocketcoder_flutter/design_system/storybook/poco_value_widget.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_poco_value_widget_stories;
import 'package:pocketcoder_flutter/design_system/storybook/notification_and_system.stories.dart'
    as _pocketcoder_flutter_design_system_storybook_notification_and_system_stories;
import 'package:widgetbook/widgetbook.dart' as _widgetbook;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookFolder(
    name: 'presentation',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'core',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'widgets',
            children: [
              _widgetbook.WidgetbookComponent(
                name: 'NotificationSettingsView',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'loaded toggles',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_notification_and_system_stories
                            .notificationSettingsLoaded,
                  ),
                ],
              ),
              _widgetbook.WidgetbookComponent(
                name: 'SystemChecksView',
                useCases: [
                  _widgetbook.WidgetbookUseCase(
                    name: 'empty checks',
                    builder:
                        _pocketcoder_flutter_design_system_storybook_notification_and_system_stories
                            .systemChecksEmpty,
                  ),
                ],
              ),
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
              )
            ],
          )
        ],
      )
    ],
  )
];
