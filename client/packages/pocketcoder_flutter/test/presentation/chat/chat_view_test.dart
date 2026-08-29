import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart'
    as ag_ui_widgets;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_view.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/chat_composer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/vim_toast.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: child),
      );

  Widget buildChatView({
    required ag_ui_widgets.Conversation conversation,
    String? chatId = 'chat-1',
    bool isLoading = false,
    bool isRunning = false,
    bool monitored = false,
    VoidCallback? onToggleMonitored,
    void Function(String)? onSendPrompt,
    Future<void> Function(String)? onRunStarted,
  }) =>
      wrap(ChatView(
        chatId: chatId,
        conversation: conversation,
        title: 'CHAT',
        isLoading: isLoading,
        isRunning: isRunning,
        requiresProviderReauthentication: false,
        modes: null,
        config: null,
        monitored: monitored,
        onToggleMonitored: onToggleMonitored ?? () {},
        onOpen: (_) {},
        onSendPrompt: onSendPrompt ?? (_) {},
        onCancel: () {},
        onSelectMode: (_) {},
        onSetOption: (_) {},
        onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
        onElicitationRespond: (_, __) {},
        animatedMessageIds: const {},
        onMessageAnimated: (_) {},
        onFiles: () {},
        onRunStarted: onRunStarted,
      ));

  testWidgets('an empty session shows the prompt with no centered title',
      (tester) async {
    await tester.pumpWidget(buildChatView(
      conversation: const ag_ui_widgets.Conversation(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ag_ui_widgets.AgUiTranscript), findsOneWidget);
    expect(find.text('root@device \$ '), findsOneWidget);
  });

  testWidgets('tapping WATCH calls onToggleMonitored', (tester) async {
    var toggled = false;
    await tester.pumpWidget(buildChatView(
      conversation: const ag_ui_widgets.Conversation(),
      onToggleMonitored: () => toggled = true,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WATCH'));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('exactly one composer is rendered', (tester) async {
    await tester.pumpWidget(buildChatView(
      conversation: const ag_ui_widgets.Conversation(),
    ));
    await tester.pumpAndSettle();

    // Guards against leaving the old standalone ChatComposer in place
    // alongside the one now supplied through composerBuilder.
    expect(find.byType(ChatComposer), findsOneWidget);
  });

  testWidgets('the composer renders below the transcript content',
      (tester) async {
    await tester.pumpWidget(buildChatView(
      conversation: ag_ui_widgets.Conversation(timeline: [
        const ag_ui_widgets.TimelineItem.text(
          id: 'm1',
          kind: ag_ui_widgets.ChatMessageKind.text,
          role: 'assistant',
          text: 'a response',
          order: ag_ui_widgets.OrderKey(0),
        ),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('root@device \$ ')).dy,
        greaterThan(tester.getTopLeft(find.textContaining('a response')).dy));
  });

  testWidgets('interrupted outcome transition shows a VimToast',
      (tester) async {
    final conversation = ag_ui_widgets.Conversation();
    Widget build(bool interrupted) => wrap(ChatView(
          chatId: 'chat-1',
          conversation: conversation,
          title: 'CHAT',
          isLoading: false,
          isRunning: false,
          requiresProviderReauthentication: false,
          modes: null,
          config: null,
          monitored: false,
          onToggleMonitored: () {},
          onOpen: (_) {},
          onSendPrompt: (_) {},
          onCancel: () {},
          onSelectMode: (_) {},
          onSetOption: (_) {},
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
          onFiles: () {},
        ));
    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(ChatView(
      chatId: 'chat-1',
      conversation: ag_ui_widgets.Conversation(
        sessionState: const ag_ui_widgets.SessionState(
          runOutcome: ag_ui_widgets.RunOutcome.interrupted,
        ),
      ),
      title: 'CHAT',
      isLoading: false,
      isRunning: false,
      requiresProviderReauthentication: false,
      modes: null,
      config: null,
      monitored: false,
      onToggleMonitored: () {},
      onOpen: (_) {},
      onSendPrompt: (_) {},
      onCancel: () {},
      onSelectMode: (_) {},
      onSetOption: (_) {},
      onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
      onElicitationRespond: (_, __) {},
      animatedMessageIds: const {},
      onMessageAnimated: (_) {},
      onFiles: () {},
    )));
    await tester.pump();
    expect(find.byType(VimToast), findsOneWidget);
    expect(find.textContaining('RUN INTERRUPTED'), findsOneWidget);
    // VimToast self-dismisses via Future.delayed(3s) -- drain it before the
    // widget tree tears down, or flutter_test's teardown invariant check
    // fails with "A Timer is still pending".
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'reauth-required transition shows a VimToast, not an inline banner',
      (tester) async {
    final conversation = ag_ui_widgets.Conversation();
    Widget build(bool requiresReauth) => wrap(ChatView(
          chatId: 'chat-1',
          conversation: conversation,
          title: 'CHAT',
          isLoading: false,
          isRunning: false,
          requiresProviderReauthentication: requiresReauth,
          modes: null,
          config: null,
          monitored: false,
          onToggleMonitored: () {},
          onOpen: (_) {},
          onSendPrompt: (_) {},
          onCancel: () {},
          onSelectMode: (_) {},
          onSetOption: (_) {},
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
          onFiles: () {},
        ));
    await tester.pumpWidget(build(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(find.byType(VimToast), findsOneWidget);
    // See the same drain comment in the interrupted-outcome test above.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('haptics once when a run completes', (tester) async {
    final haptics = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    ChatView view({
      required bool isRunning,
      required ag_ui_widgets.Conversation conversation,
    }) =>
        ChatView(
          chatId: 'chat-1',
          conversation: conversation,
          title: 'CHAT',
          isLoading: isRunning,
          isRunning: isRunning,
          requiresProviderReauthentication: false,
          modes: null,
          config: null,
          monitored: false,
          onToggleMonitored: () {},
          onOpen: (_) {},
          onSendPrompt: (_) {},
          onCancel: () {},
          onSelectMode: (_) {},
          onSetOption: (_) {},
          onPermissionOptionSelected: (_, {optionId, cancelled = false}) {},
          onElicitationRespond: (_, __) {},
          animatedMessageIds: const {},
          onMessageAnimated: (_) {},
          onFiles: () {},
        );

    await tester.pumpWidget(wrap(view(
      isRunning: true,
      conversation: const ag_ui_widgets.Conversation(),
    )));
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(view(
      isRunning: false,
      conversation: const ag_ui_widgets.Conversation(
        sessionState: ag_ui_widgets.SessionState(
          runOutcome: ag_ui_widgets.RunOutcome.success,
        ),
      ),
    )));
    await tester.pumpAndSettle();

    expect(haptics, hasLength(1));
    expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');

    await tester.pumpWidget(wrap(view(
      isRunning: false,
      conversation: const ag_ui_widgets.Conversation(
        sessionState: ag_ui_widgets.SessionState(
          runOutcome: ag_ui_widgets.RunOutcome.success,
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(haptics, hasLength(1));
  });

  testWidgets('starts the foreground activity when a monitored run begins',
      (tester) async {
    final startedChats = <String>[];

    await tester.pumpWidget(buildChatView(
      conversation: const ag_ui_widgets.Conversation(),
      isRunning: false,
      monitored: true,
      onRunStarted: (chatId) async => startedChats.add(chatId),
    ));
    await tester.pump();
    await tester.pumpWidget(buildChatView(
      conversation: const ag_ui_widgets.Conversation(),
      isRunning: true,
      monitored: true,
      onRunStarted: (chatId) async => startedChats.add(chatId),
    ));
    await tester.pump();

    expect(startedChats, ['chat-1']);
  });

  testWidgets('does not start the foreground activity for an unmonitored run',
      (tester) async {
    final startedChats = <String>[];

    await tester.pumpWidget(buildChatView(
      conversation: const ag_ui_widgets.Conversation(),
      isRunning: false,
      monitored: false,
      onRunStarted: (chatId) async => startedChats.add(chatId),
    ));
    await tester.pump();
    await tester.pumpWidget(buildChatView(
      conversation: const ag_ui_widgets.Conversation(),
      isRunning: true,
      monitored: false,
      onRunStarted: (chatId) async => startedChats.add(chatId),
    ));
    await tester.pump();

    expect(startedChats, isEmpty);
  });

  testWidgets('submitting re-arms follow after the user scrolled back',
      (tester) async {
    await tester.pumpWidget(buildChatView(
      conversation: ag_ui_widgets.Conversation(timeline: [
        for (var i = 0; i < 40; i++)
          ag_ui_widgets.TimelineItem.text(
            id: 'm$i',
            kind: ag_ui_widgets.ChatMessageKind.text,
            role: 'assistant',
            text: 'line $i',
            order: ag_ui_widgets.OrderKey(i),
          ),
      ]),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1500));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField, skipOffstage: false), 'next prompt');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final position = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller
        ?.position;
    expect(position?.pixels,
        moreOrLessEquals(position?.maxScrollExtent ?? 0, epsilon: 1));
  });
}
