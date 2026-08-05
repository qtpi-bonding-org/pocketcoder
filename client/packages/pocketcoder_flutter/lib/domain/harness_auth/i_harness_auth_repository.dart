import 'harness_auth_models.dart';

abstract class IHarnessAuthRepository {
  Future<HarnessAuthStatus> status({
    required String harnessId,
    String? attemptId,
  });

  Future<HarnessAuthStatus> start({
    required String harnessId,
    required String credentialMode,
    String? provider,
    String? providerKey,
  });

  Future<HarnessAuthStatus> poll({
    required String harnessId,
    String? attemptId,
  });

  Future<HarnessAuthStatus> submit({
    required String harnessId,
    required String code,
    String? attemptId,
  });

  Future<HarnessAuthStatus> cancel({
    required String harnessId,
    String? attemptId,
  });

  Future<HarnessAuthStatus> disconnect({required String harnessId});
}
