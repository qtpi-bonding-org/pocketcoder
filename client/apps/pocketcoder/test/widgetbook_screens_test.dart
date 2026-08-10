import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_app/widgetbook_screens.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  testWidgets('every Screens story renders without an exception',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final components = _components(screenDirectories).toList();
    final stories = _useCases(screenDirectories).toList();
    expect(
      components.map((component) => component.name).toSet(),
      _screenInventory,
    );
    expect(components, hasLength(34));
    expect(stories, hasLength(60));

    for (final story in stories) {
      await tester.pumpWidget(Builder(builder: story.builder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Screens story failed: ${story.name}',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Iterable<WidgetbookComponent> _components(
  Iterable<WidgetbookNode> nodes,
) sync* {
  for (final node in nodes) {
    if (node case WidgetbookComponent component) {
      yield component;
    }
    yield* _components(node.children ?? const []);
  }
}

Iterable<WidgetbookUseCase> _useCases(Iterable<WidgetbookNode> nodes) sync* {
  for (final node in nodes) {
    if (node case WidgetbookUseCase useCase) {
      yield useCase;
    } else {
      yield* _useCases(node.children ?? const []);
    }
  }
}

const _screenInventory = {
  'BootScreen',
  'OnboardingScreen',
  'OnboardingLoginScreen',
  'OnboardingDeployCredentialsScreen',
  'HarnessChoiceScreen',
  'HarnessAuthorizationScreen',
  'HarnessAuthScreen',
  'DeployPickerScreen',
  'ProviderScreen',
  'AgentConfigScreen',
  'SettingsScreen',
  'SkillsScreen',
  'SchedulerScreen',
  'McpManagementScreen',
  'ToolPermissionsScreen',
  'SystemChecksScreen',
  'NotificationSettingsScreen',
  'ErrorInboxScreen',
  'AgentObservabilityScreen',
  'MonitorScreen',
  'PermissionRelayScreen',
  'ChatListScreen',
  'ChatScreen',
  'TerminalCommandCard',
  'PermissionCard',
  'ElicitationCard',
  'FileBrowserScreen',
  'FileViewerScreen',
  'AuthScreen',
  'ConfigScreen',
  'ProgressScreen',
  'ProvisioningLessonCard',
  'DetailsScreen',
  'UpdateServerScreen',
};
