import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/status/i_status_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_screen.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockStatusRepository extends Mock implements IStatusRepository {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockAuthRepository authRepo;
  late MockStatusRepository statusRepo;
  late MockFlutterSecureStorage secureStorage;

  setUp(() {
    authRepo = MockAuthRepository();
    statusRepo = MockStatusRepository();
    when(() => statusRepo.checkPocketBaseHealth())
        .thenAnswer((_) async => true);

    getIt.registerFactory<AuthCubit>(() => AuthCubit(authRepo));
    getIt.registerFactory<IStatusRepository>(() => statusRepo);
    // OnboardingScreen's no-prefill path calls _restoreSavedUrl(), which
    // reads getIt<FlutterSecureStorage>() -- must be registered even
    // though this test never asserts on its value.
    secureStorage = MockFlutterSecureStorage();
    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    getIt.registerFactory<FlutterSecureStorage>(() => secureStorage);
  });

  tearDown(() {
    getIt.reset();
  });

  Widget buildTestable({OnboardingPrefill? prefill}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PocoCubit>(create: (_) => PocoCubit()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(prefill: prefill),
      ),
    );
  }

  testWidgets('pre-fills url/email/password fields when prefill is given',
      (tester) async {
    await tester.pumpWidget(buildTestable(
      prefill: const OnboardingPrefill(
        url: 'https://1.2.3.4.sslip.io',
        email: 'admin@pocketcoder.local',
        password: 'correct-horse-battery-staple',
      ),
    ));
    await tester.pump();

    expect(find.text('https://1.2.3.4.sslip.io'), findsOneWidget);
    expect(find.text('admin@pocketcoder.local'), findsOneWidget);
    expect(find.text('correct-horse-battery-staple'), findsOneWidget);
  });

  testWidgets('falls back to the default local url when no prefill is given',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pump();

    // findsWidgets, not findsOneWidget: TerminalTextField's hint text is
    // coincidentally the same string as the default value, so it's
    // rendered twice (the field's real EditableText plus its own hint
    // label) purely because hint == value here, not a real duplicate.
    expect(find.text('http://127.0.0.1:8090'), findsWidgets);
  });
}