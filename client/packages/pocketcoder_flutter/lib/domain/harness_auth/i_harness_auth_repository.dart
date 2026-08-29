import 'harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/credential_selection.dart';
import 'package:pocketcoder_flutter/domain/models/harness_oauth_account.dart';

abstract class IHarnessAuthRepository {
  Stream<List<HarnessOauthAccount>> watchHarnessOAuthAccounts();
  Stream<List<CredentialSelection>> watchCredentialSelections();
  Future<HarnessAuthStatus> status({
    required String harnessId,
    required String provider,
    String? accountId,
    String? attemptId,
  });

  Future<HarnessAuthStatus> start({
    required String harnessId,
    required String provider,
    required String mode,
    required String visibility,
    String? accountId,
    String? accountName,
  });

  Future<HarnessAuthStatus> poll({
    required String harnessId,
    required String provider,
    String? accountId,
    String? attemptId,
  });

  Future<HarnessAuthStatus> submit({
    required String harnessId,
    required String provider,
    required String code,
    String? accountId,
    String? attemptId,
  });

  Future<HarnessAuthStatus> cancel({
    required String harnessId,
    required String provider,
    String? accountId,
    String? attemptId,
  });

  Future<HarnessAuthStatus> disconnect({
    required String harnessId,
    required String provider,
    String? accountId,
  });
}
