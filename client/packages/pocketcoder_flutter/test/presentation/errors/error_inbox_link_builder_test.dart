import 'package:flutter/material.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/notifying_error_box_storage.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/errors/error_inbox_link_builder.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

class _MemoryErrorBoxStorage implements ErrorBoxStorage {
  final entries = <ErrorBoxEntry>[];

  @override
  Future<void> saveError(ErrorEntry error) async {
    entries.add(ErrorBoxEntry(
      id: 'e${entries.length}',
      fingerprint: 'fp${entries.length}',
      errorData: error,
      occurrenceCount: 1,
      firstOccurred: error.timestamp,
      lastOccurred: error.timestamp,
    ));
  }

  @override
  Future<List<ErrorBoxEntry>> getUnsentErrors() async => List.of(entries);

  @override
  Future<ErrorBoxEntry?> getErrorById(String id) async => null;

  @override
  Future<void> markAsSent(String id) async {}

  @override
  Future<void> deleteError(String id) async =>
      entries.removeWhere((e) => e.id == id);

  @override
  Future<int> getUnsentCount() async => entries.length;
}

class _FailingCubit extends AppCubit<ErrorInboxState> {
  _FailingCubit() : super(const ErrorInboxState());

  Future<void> fail() => tryOperation(() => throw StateError('login failed'));
}

void main() {
  late _MemoryErrorBoxStorage memory;

  setUp(() {
    memory = _MemoryErrorBoxStorage();
    ErrorPrivserver.configure(ErrorPrivserverConfig(
      storage: NotifyingErrorBoxStorage(memory),
      reporter: (_) async => false,
      errorCodeMapper: (_) => 'ERR_TEST',
      exceptionMapper: (_) => null,
    ));
  });

  GoRouter router() => GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: ErrorInboxLinkBuilder()),
        ),
        GoRoute(
          path: AppRoutes.statusErrors,
          name: RouteNames.statusErrors,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                memory.entries.clear();
                context.pop();
              },
              child: const Text('clear and back'),
            ),
          ),
        ),
      ]);

  Future<void> pumpLink(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows errors (0) when the inbox is empty', (tester) async {
    await pumpLink(tester);

    expect(find.text('<errors (0)>'), findsOneWidget);
  });

  testWidgets('counts a failure once its capture has been saved',
      (tester) async {
    await pumpLink(tester);

    final cubit = _FailingCubit();
    addTearDown(cubit.close);
    await cubit.fail();
    await tester.pumpAndSettle();

    expect(find.text('<errors (1)>'), findsOneWidget);
  });

  testWidgets('opens the inbox and reloads the count on return',
      (tester) async {
    await memory.saveError(ErrorEntry(
      source: 'AuthCubit',
      errorType: 'StateError',
      errorCode: 'ERR_TEST',
      stackTrace: '#0',
      timestamp: DateTime(2026),
    ));
    await pumpLink(tester);
    expect(find.text('<errors (1)>'), findsOneWidget);

    await tester.tap(find.text('<errors (1)>'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('clear and back'));
    await tester.pumpAndSettle();

    expect(find.text('<errors (0)>'), findsOneWidget);
  });
}
