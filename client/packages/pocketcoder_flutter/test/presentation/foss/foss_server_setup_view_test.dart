import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/domain/security/i_ssh_key_generator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_cubit.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_connection_tester.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/foss/foss_server_setup_view.dart';

class _FakeKeyGenerator implements ISshKeyGenerator {
  @override
  Future<({String publicKey, String privateKey})> generate() async => (
        publicKey: 'ssh-ed25519 AAAAtest pocketcoder',
        privateKey: 'PRIVATE-PEM'
      );
  @override
  Future<({String publicKey, String privateKey})> generateHostKeyPair() async =>
      throw UnimplementedError('not used by this view');
}

class _FakeTester implements IFossRootSshConnectionTester {
  @override
  Future<FossHostIdentity> testConnection({
    required String host,
    required String privateKeyPem,
  }) async =>
      const FossHostIdentity(
          hostKeyType: 'ssh-ed25519', hostKeyFingerprint: 'SHA256:abc');
}

class _MockStore extends Mock implements FossRootSshCredentialsStore {}

Widget _wrap(FossServerSetupCubit cubit,
        {required VoidCallback onSetupComplete}) =>
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: BlocProvider<FossServerSetupCubit>.value(
        value: cubit,
        child: FossServerSetupView(onSetupComplete: onSetupComplete),
      ),
    );

void main() {
  late _MockStore store;
  late FossServerSetupCubit cubit;

  setUpAll(() {
    registerFallbackValue(const FossRootSshCredentials(
      publicKey: '',
      privateKey: '',
      hostKeyType: '',
      hostKeyFingerprint: '',
    ));
  });

  setUp(() {
    store = _MockStore();
    when(() => store.save(any())).thenAnswer((_) async {});
    cubit = FossServerSetupCubit(
      _FakeKeyGenerator(),
      _FakeTester(),
      store,
      PocketBase('https://my-server.example'),
    );
  });

  testWidgets('idle phase shows a GENERATE KEY action and no public key yet',
      (tester) async {
    await tester.pumpWidget(_wrap(cubit, onSetupComplete: () {}));

    expect(find.text('<GENERATE KEY>'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets(
      'tapping GENERATE KEY shows the public key and the derived host, '
      'with no editable host field', (tester) async {
    await tester.pumpWidget(_wrap(cubit, onSetupComplete: () {}));

    await tester.tap(find.text('<GENERATE KEY>'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ssh-ed25519 AAAAtest pocketcoder'),
        findsOneWidget);
    expect(find.textContaining('my-server.example'), findsOneWidget);
    expect(find.byType(TextField), findsNothing,
        reason: 'the host is derived from PocketBase, never user-entered '
            '-- see Task 4\'s design note on why');
  });

  testWidgets(
      'a full generate -> test & save flow shows CONNECTED and invokes '
      'onSetupComplete exactly once', (tester) async {
    var completions = 0;
    await tester.pumpWidget(_wrap(cubit, onSetupComplete: () => completions++));

    await tester.tap(find.text('<GENERATE KEY>'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('<TEST CONNECTION & SAVE>'));
    await tester.pumpAndSettle();

    expect(
        find.text('CONNECTED -- YOUR SERVER IS NOW MANAGED'), findsOneWidget);
    expect(completions, 1);
    verify(() => store.save(any())).called(1);
  });
}
