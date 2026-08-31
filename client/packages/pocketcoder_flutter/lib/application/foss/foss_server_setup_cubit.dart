import 'package:pocketcoder_flutter/domain/security/i_ssh_key_generator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_state.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_connection_tester.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';

class FossServerSetupCubit extends Cubit<FossServerSetupState> {
  FossServerSetupCubit(
    this._keyGenerator,
    this._tester,
    this._store,
    PocketBase pocketBase,
  )   : host = Uri.parse(pocketBase.baseURL).host,
        super(const FossServerSetupState());

  final ISshKeyGenerator _keyGenerator;
  final IFossRootSshConnectionTester _tester;
  final FossRootSshCredentialsStore _store;
  final String host;

  String? _privateKey;

  Future<void> generateKey() async {
    if (state.phase == FossServerSetupPhase.connected) return;
    final keyPair = await _keyGenerator.generate();
    _privateKey = keyPair.privateKey;
    emit(state.copyWith(
      phase: FossServerSetupPhase.keyReady,
      publicKey: keyPair.publicKey,
      clearError: true,
    ));
  }

  Future<void> testAndSave() async {
    if (state.phase == FossServerSetupPhase.connected) return;
    final privateKey = _privateKey;
    final publicKey = state.publicKey;
    if (privateKey == null || publicKey == null) return;

    emit(state.copyWith(phase: FossServerSetupPhase.testing, clearError: true));
    try {
      final identity = await _tester.testConnection(
        host: host,
        privateKeyPem: privateKey,
      );
      await _store.save(FossRootSshCredentials(
        publicKey: publicKey,
        privateKey: privateKey,
        hostKeyType: identity.hostKeyType,
        hostKeyFingerprint: identity.hostKeyFingerprint,
      ));
      emit(state.copyWith(phase: FossServerSetupPhase.connected));
    } on Object catch (error) {
      emit(state.copyWith(
        phase: FossServerSetupPhase.keyReady,
        error: error.toString(),
      ));
    }
  }
}
