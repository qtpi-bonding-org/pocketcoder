// Widget tests for the post-deployment DetailsScreen's credential handoff:
// password row reveal/copy and the LOG IN NOW navigation. Mirrors the
// getIt-registration pattern used in tests/presentation/settings/.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:flutter_aeroform/domain/models/instance_credentials.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_pro/presentation/deployment/details_screen.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_credentials.dart';

class MockDeploymentCubit extends Mock implements DeploymentCubit {}

class MockSecureStorage extends Mock implements ISecureStorage {}
class MockPocketCoderCredentialStore extends Mock
    implements PocketCoderCredentialStore {}

void main() {
  late MockDeploymentCubit cubit;
  late MockSecureStorage secureStorage;
  late Instance instance;
  late InstanceCredentials credentials;
  late MockPocketCoderCredentialStore credentialStore;

  setUp(() {
    instance = Instance(
      id: 'inst-1',
      label: 'pocketcoder-inst-1',
      ipAddress: '1.2.3.4',
      status: InstanceStatus.running,
      region: 'us-east',
      planType: 'nanode',
      provider: 'linode',
      created: DateTime(2026, 1, 1),
    );
    // Instance.httpsUrl is a derived getter -- for ipAddress '1.2.3.4' it
    // evaluates to 'https://1-2-3-4.sslip.io' (dots become hyphens), not a
    // constructor field, so nothing to pass in above.
    credentials = const InstanceCredentials(
      instanceId: 'inst-1',
      rootSshPrivateKey: 'not-used-here',
    );

    cubit = MockDeploymentCubit();
    when(() => cubit.state).thenReturn(
      DeploymentState.initial().copyWith(instance: instance),
    );
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.refreshInstanceStatus(any())).thenAnswer((_) async {});
    when(() => cubit.cancelDeployment()).thenReturn(null);

    secureStorage = MockSecureStorage();
    when(() => secureStorage.getInstanceCredentials('inst-1'))
        .thenAnswer((_) async => credentials);
    credentialStore = MockPocketCoderCredentialStore();
    when(() => credentialStore.get('inst-1')).thenAnswer((_) async =>
        const PocketCoderCredentials(
          instanceId: 'inst-1',
          adminEmail: 'admin@pocketcoder.local',
          adminPassword: 'correct-horse-battery-staple',
        ));

    GetIt.I.registerFactory<ISecureStorage>(() => secureStorage);
    GetIt.I.registerFactory<PocketCoderCredentialStore>(() => credentialStore);
    GetIt.I.registerFactory<DeploymentMessageMapper>(
        () => DeploymentMessageMapper());
  });

  tearDown(() {
    GetIt.I.reset();
  });

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/deployment/details',
      routes: [
        GoRoute(
          path: '/deployment/details',
          name: 'deploymentDetails',
          builder: (context, state) => BlocProvider<DeploymentCubit>.value(
            value: cubit,
            child: const DetailsScreen(instanceId: 'inst-1'),
          ),
        ),
        GoRoute(
          path: '/onboarding/login',
          name: 'onboardingLogin',
          builder: (context, state) => Text(
              'onboarding-login:${(state.extra as OnboardingPrefill?)?.email}'),
        ),
      ],
    );

    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }

  testWidgets('password is masked by default, reveals on tap', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('correct-horse-battery-staple'), findsNothing);
    expect(
      find.text('•' * 'correct-horse-battery-staple'.length),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(find.text('correct-horse-battery-staple'), findsOneWidget);
  });

  testWidgets('copy icon puts the password on the clipboard', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.content_copy).last);
    await tester.pump();

    expect(copied, contains('correct-horse-battery-staple'));
  });

  testWidgets('LOG IN NOW navigates to PocketBase login with prefill',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOG IN NOW'));
    await tester.pumpAndSettle();

    expect(
        find.text('onboarding-login:admin@pocketcoder.local'), findsOneWidget);
  });
}
