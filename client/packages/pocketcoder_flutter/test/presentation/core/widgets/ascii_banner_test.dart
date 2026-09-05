import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart'
    as ag_ui_widgets;
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_list_view.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_view.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: child,
    );

ChatListView _chatList({int chats = 0}) => ChatListView(
      state: ChatListState(
        status: UiFlowStatus.success,
        chats: [
          for (var i = 0; i < chats; i++)
            Chat(id: 'c$i', title: 'chat $i', user: 'u'),
        ],
      ),
      onNewChat: () {},
      onOpen: (_) {},
      onArchive: (_) {},
      onDelete: (_) {},
    );

void main() {
  test('every pillar has a banner', () {
    for (final pillar in NavPillar.values) {
      expect(AppAscii.bannerFor(pillar), isNotEmpty,
          reason: 'no banner for $pillar');
    }
  });

  test('all four banners are the same width', () {
    // AsciiLogo renders art inside a FittedBox(scaleDown), which scales each
    // banner independently. Equal widths mean one shared scale factor, so the
    // letterforms stay the same size as the user moves between nav tabs.
    // Art is exempt from the 36-column text floor -- it scales rather than
    // wrapping or truncating -- so width is only a consistency question.
    final widths = {
      for (final pillar in NavPillar.values)
        pillar: AppAscii.bannerFor(pillar)
            .split('\n')
            .map((l) => l.length)
            .reduce((a, b) => a > b ? a : b),
    };
    expect(widths.values.toSet(), hasLength(1),
        reason: 'banners must share one width or they render at different '
            'sizes per tab. Pad the narrower ones with trailing spaces: '
            '$widths');
  });

  test('each banner is internally rectangular', () {
    for (final pillar in NavPillar.values) {
      final lines = AppAscii.bannerFor(pillar).split('\n');
      expect(lines.map((l) => l.length).toSet(), hasLength(1),
          reason: '$pillar has ragged lines; FittedBox fits the widest one, '
              'so short lines shift the art off-centre');
    }
  });

  testWidgets('the chats nav root renders its banner', (tester) async {
    await tester.pumpWidget(_wrap(_chatList()));

    final logo = tester.widget<AsciiLogo>(find.byType(AsciiLogo));
    expect(logo.text, AppAscii.bannerFor(NavPillar.chat));
  });

  testWidgets('a back screen renders no banner', (tester) async {
    await tester.pumpWidget(_wrap(ChatView(
      chatId: 'chat-1',
      conversation: const ag_ui_widgets.Conversation(),
      title: 'CHAT',
      isLoading: false,
      isRunning: false,
      requiresProviderReauthentication: false,
      config: null,
      showMonitorAction: false,
      monitored: false,
      onToggleMonitored: () {},
      onOpen: (_) {},
      onSendPrompt: (_) {},
      onCancel: () {},
      onSetOption: (_) {},
      onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
      onElicitationRespond: (_, __) {},
      animatedMessageIds: const {},
      onMessageAnimated: (_) {},
      onFiles: () {},
    )));

    expect(find.byType(AsciiLogo), findsNothing);
  });

  testWidgets('the chats nav root fits a short viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // An empty list cannot overflow, so the banner only earns its keep as a
    // regression test against a list long enough to fill the viewport.
    await tester.pumpWidget(_wrap(_chatList(chats: 20)));
    expect(tester.takeException(), isNull);
  });
}
