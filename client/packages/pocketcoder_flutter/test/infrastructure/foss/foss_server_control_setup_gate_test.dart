import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_server_control_setup_gate.dart';
import 'package:pocketcoder_flutter/presentation/foss/foss_server_setup_view.dart';

class _MockStore extends Mock implements FossRootSshCredentialsStore {}

void main() {
  test('returns null (proceed normally) when credentials already exist',
      () async {
    final store = _MockStore();
    when(() => store.load())
        .thenAnswer((_) async => const FossRootSshCredentials(
              publicKey: 'PUB',
              privateKey: 'PRIV',
              hostKeyType: 'ssh-ed25519',
              hostKeyFingerprint: 'SHA256:abc',
            ));
    final gate = FossServerControlSetupGate(store);

    expect(await gate.resolveSetupScreen(onSetupComplete: () {}), isNull);
  });

  test('returns the setup view when nothing has been configured yet', () async {
    final store = _MockStore();
    when(() => store.load()).thenAnswer((_) async => null);
    final gate = FossServerControlSetupGate(store);

    final widget = await gate.resolveSetupScreen(onSetupComplete: () {});

    expect(widget, isA<BlocProvider>());
    expect((widget! as BlocProvider).child, isA<FossServerSetupView>());
  });
}
