// test/presentation/errors/error_inbox_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_cubit.dart';
import 'package:pocketcoder_flutter/presentation/errors/adapters/error_inbox_adapter.dart';
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
      reporter: (_) async => false,
      errorCodeMapper: (_) => 'ERR_TEST',
      exceptionMapper: (_) => null,
    ));
  });

  testWidgets('renders a captured entry', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);

    await tester.pumpWidget(_wrap(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ErrorInboxCubit()..loadErrors()),
        ],
        child: const ErrorInboxAdapter(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ChatCubit'), findsOneWidget);
    expect(find.textContaining('CHAT_001'), findsOneWidget);
  });

  testWidgets('shows empty state with no entries', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ErrorInboxCubit()..loadErrors()),
        ],
        child: const ErrorInboxAdapter(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NO ERRORS CAPTURED'), findsOneWidget);
  });

  testWidgets('delete removes an entry', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);
    when(() => storage.deleteError('e1')).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ErrorInboxCubit()..loadErrors()),
        ],
        child: const ErrorInboxAdapter(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    verify(() => storage.deleteError('e1')).called(1);
  });
}
