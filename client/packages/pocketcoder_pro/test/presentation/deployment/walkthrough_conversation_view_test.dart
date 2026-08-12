import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/walkthrough_conversation_view.dart';

void main() {
  testWidgets('renders guided turns, snippet, and suggested prompts',
      (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WalkthroughConversationView(
            progressLabel: 'NIXOS SERVER SETUP · WALKTHROUGH 01 / 05',
            briefTitle: 'Network boundaries',
            entries: const [
              WalkthroughConversationEntry(
                speaker: TerminalConversationSpeaker.poco,
                message: 'These rules keep public and private traffic apart.',
              ),
            ],
            snippet: const Text('snippet'),
            suggestions: const ['Why does Docker need rules?'],
            onSuggestionSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('NETWORK BOUNDARIES'), findsOneWidget);
    expect(find.text('snippet'), findsOneWidget);
    expect(find.text('> WHY DOES DOCKER NEED RULES?'), findsOneWidget);

    await tester.tap(find.text('> WHY DOES DOCKER NEED RULES?'));
    expect(selected, 'Why does Docker need rules?');
  });

  testWidgets('renders walkthrough boundary and brief separator',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WalkthroughConversationView(
            progressLabel: 'NIXOS SERVER SETUP · WALKTHROUGH 02 / 05',
            briefTitle: 'Release source',
            entries: const [],
            snippet: const Text('snippet'),
            suggestions: const [],
            onSuggestionSelected: (_) {},
            walkthroughBoundary: const WalkthroughConversationBoundary(
              label: 'WALKTHROUGH 02 / 05 · DEPLOYMENT',
              message: 'Now we will follow the verified release onto the host.',
            ),
            showBriefDivider: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('WALKTHROUGH 02 / 05 · DEPLOYMENT'), findsOneWidget);
    expect(
      find.textContaining('Now we will follow the verified release'),
      findsOneWidget,
    );
    expect(find.text('BRIEF'), findsOneWidget);
  });

  testWidgets('renders and selects prepared FAQ prompts', (tester) async {
    WalkthroughFaqPrompt? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WalkthroughConversationView(
            progressLabel: 'WALKTHROUGH 01 / 03 · BRIEF 01 / 02',
            briefTitle: 'Verified release',
            entries: const [],
            snippet: const SizedBox.shrink(),
            suggestions: const [],
            onSuggestionSelected: (_) {},
            faqPrompts: const [
              WalkthroughFaqPrompt(
                question: 'What does verified mean?',
                answer: 'The release matches its expected fingerprint.',
              ),
            ],
            onFaqSelected: (prompt) => selected = prompt,
          ),
        ),
      ),
    );

    await tester.tap(find.text('> WHAT DOES VERIFIED MEAN?'));
    expect(selected?.answer, 'The release matches its expected fingerprint.');
  });

  testWidgets('wraps long conversation content on a narrow mobile layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WalkthroughConversationView(
            progressLabel: 'WALKTHROUGH 05 / 05 · BRIEF 04 / 04',
            briefTitle:
                'A deliberately long brief title that must remain readable',
            entries: const [
              WalkthroughConversationEntry(
                speaker: TerminalConversationSpeaker.poco,
                message:
                    'This is a long explanation that should wrap naturally on a phone without creating horizontal overflow or clipping the Poco bubble.',
              ),
            ],
            snippet: const SizedBox(
              height: 420,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text('a very long source line that can scroll safely'),
              ),
            ),
            suggestions: const [],
            onSuggestionSelected: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
