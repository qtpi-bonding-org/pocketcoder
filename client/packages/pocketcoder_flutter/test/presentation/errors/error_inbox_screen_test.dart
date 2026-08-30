// test/presentation/errors/error_inbox_screen_test.dart
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/application/errors/error_inbox_cubit.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/errors/adapters/error_inbox_adapter.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';

class MockErrorBoxStorage extends Mock implements ErrorBoxStorage {}

class _FakeReleaseStatusService implements IServerReleaseStatusService {
  @override
  bool get isAuthenticated => false;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<ServerReleaseStatusSnapshot> inspect() =>
      throw UnimplementedError('not authenticated in this test');
}

class _FakeInAppBrowserLauncher implements InAppBrowserLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class _NoopFeedbackService implements IFeedbackService {
  @override
  void show(FeedbackMessage message) {}
}

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
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockErrorBoxStorage storage;
  late _FakeInAppBrowserLauncher launcher;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'PocketCoder',
      packageName: 'org.pocketcoder.app',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    storage = MockErrorBoxStorage();
    ErrorPrivserver.configure(
      ErrorPrivserverConfig(
        storage: storage,
        reporter: (_) async => false,
        errorCodeMapper: (_) => 'ERR_TEST',
        exceptionMapper: (_) => null,
      ),
    );
    launcher = _FakeInAppBrowserLauncher();
    GetIt.instance.registerSingleton<IServerReleaseStatusService>(
      _FakeReleaseStatusService(),
    );
    GetIt.instance.registerSingleton<InAppBrowserLauncher>(launcher);
    GetIt.instance.registerSingleton<IFeedbackService>(_NoopFeedbackService());
  });

  tearDown(GetIt.instance.reset);

  testWidgets('renders a captured entry', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);

    await tester.pumpWidget(
      _wrap(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ErrorInboxCubit()..loadErrors()),
          ],
          child: const ErrorInboxAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // BiosRow renders BIOS labels in its standard uppercase treatment.
    expect(find.text('CHATCUBIT'), findsOneWidget);
    expect(find.textContaining('CHAT_001'), findsOneWidget);
    expect(find.byType(BiosCard), findsOneWidget);
    expect(find.byType(BiosRow), findsWidgets);
    expect(find.text('#0 fake stack'), findsNothing);

    await tester.tap(find.byType(BiosRow).first);
    await tester.pumpAndSettle();

    expect(find.text('#0 fake stack'), findsOneWidget);
  });

  testWidgets('shows empty state with no entries', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => []);

    await tester.pumpWidget(
      _wrap(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ErrorInboxCubit()..loadErrors()),
          ],
          child: const ErrorInboxAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NO ERRORS CAPTURED'), findsOneWidget);
  });

  testWidgets('delete removes an entry', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);
    when(() => storage.deleteError('e1')).thenAnswer((_) async {});

    await tester.pumpWidget(
      _wrap(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ErrorInboxCubit()..loadErrors()),
          ],
          child: const ErrorInboxAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    verify(() => storage.deleteError('e1')).called(1);
  });

  testWidgets(
      'REPORT ON GITHUB copies the report with the app version and opens '
      'a pre-filled new-issue URL', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      _wrap(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ErrorInboxCubit()..loadErrors()),
          ],
          child: const ErrorInboxAdapter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BiosRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('REPORT ON GITHUB'));
    await tester.pumpAndSettle();

    expect(clipboardText, contains('App version: 1.2.3+45'));
    expect(clipboardText, contains('CHAT_001'));
    expect(launcher.opened, hasLength(1));
    expect(
      launcher.opened.single.toString(),
      'https://github.com/qtpi-bonding-org/pocketcoder/issues/new'
      '?title=ChatCubit%3A+CHAT_001',
    );
  });
}
