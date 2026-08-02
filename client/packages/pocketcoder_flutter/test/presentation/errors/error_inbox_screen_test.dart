// test/presentation/errors/error_inbox_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/presentation/errors/error_inbox_screen.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class MockErrorBoxStorage extends Mock implements ErrorBoxStorage {}

final _entry = ErrorBoxEntry(
  id: 'e1',
  fingerprint: 'fp1',
  errorData: ErrorEntry(
    source: 'ChatCubit',
    errorType: 'ChatException',
    errorCode: 'CHAT_001',
    stackTrace: '#0 fake stack',
    timestamp: DateTime(2026, 1, 1),
  ),
  occurrenceCount: 3,
  firstOccurred: DateTime(2026, 1, 1),
  lastOccurred: DateTime(2026, 1, 2),
);

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  late MockErrorBoxStorage storage;

  setUp(() {
    storage = MockErrorBoxStorage();
    ErrorPrivserver.configure(ErrorPrivserverConfig(
      storage: storage,
      reporter: (_) async {},
      errorCodeMapper: (_) => 'ERR_TEST',
      exceptionMapper: (_) => null,
      showToast: false,
      toastBuilder: _FakeToastBuilder(),
      pageBuilder: _FakePageBuilder(),
    ));
  });

  testWidgets('renders a captured entry', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);

    await tester.pumpWidget(_wrap(
      BlocProvider(
        create: (_) => ErrorBoxPageCubit()..loadErrors(),
        child: const ErrorInboxScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ChatCubit'), findsOneWidget);
    expect(find.textContaining('CHAT_001'), findsOneWidget);
  });

  testWidgets('shows empty state with no entries', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(
      BlocProvider(
        create: (_) => ErrorBoxPageCubit()..loadErrors(),
        child: const ErrorInboxScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NO ERRORS CAPTURED'), findsOneWidget);
  });

  testWidgets('delete removes an entry', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);
    when(() => storage.deleteError('e1')).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(
      BlocProvider(
        create: (_) => ErrorBoxPageCubit()..loadErrors(),
        child: const ErrorInboxScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    verify(() => storage.deleteError('e1')).called(1);
  });
}

class _FakeToastBuilder extends ErrorToastBuilder {
  @override
  void show(BuildContext context, String message,
      {required VoidCallback onDismiss, required VoidCallback onSend}) {}
}

class _FakePageBuilder extends ErrorBoxPageBuilder {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}