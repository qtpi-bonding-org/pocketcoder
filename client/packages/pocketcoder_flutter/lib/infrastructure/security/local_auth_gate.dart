import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pocketcoder_flutter/domain/security/i_local_auth_gate.dart';

@LazySingleton(as: ILocalAuthGate)
class LocalAuthGate implements ILocalAuthGate {
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      if (!await _localAuth.canCheckBiometrics &&
          !await _localAuth.isDeviceSupported()) {
        return false;
      }
      return await _localAuth.authenticate(localizedReason: reason);
    } on Object {
      return false;
    }
  }
}
