import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_exception.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

class HarnessAuthRepository implements IHarnessAuthRepository {
  HarnessAuthRepository(this._pb, this._authRepo);

  final PocketBase _pb;
  final IAuthRepository _authRepo;

  @override
  Future<HarnessAuthStatus> status({
    required String harnessId,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      path: ApiEndpoints.harnessAuthStatus,
      body: _accountPayload(
        harnessId: harnessId,
        accountId: accountId,
        attemptId: attemptId,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> start({
    required String harnessId,
    required String credentialMode,
    required String visibility,
    String? accountId,
    String? accountName,
    String? provider,
    String? providerKey,
  }) {
    return _sendStatus(
      path: ApiEndpoints.harnessAuthStart,
      body: _accountPayload(
        harnessId: harnessId,
        accountId: accountId,
        accountName: accountName,
        visibility: visibility,
        credentialMode: credentialMode,
        provider: provider,
        providerKey: providerKey,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> poll({
    required String harnessId,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      path: ApiEndpoints.harnessAuthPoll,
      body: _accountPayload(
        harnessId: harnessId,
        accountId: accountId,
        attemptId: attemptId,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> submit({
    required String harnessId,
    required String code,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      path: ApiEndpoints.harnessAuthSubmit,
      body: _accountPayload(
        harnessId: harnessId,
        accountId: accountId,
        attemptId: attemptId,
        code: code,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> cancel({
    required String harnessId,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      path: ApiEndpoints.harnessAuthCancel,
      body: _accountPayload(
        harnessId: harnessId,
        accountId: accountId,
        attemptId: attemptId,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> disconnect({
    required String harnessId,
    String? accountId,
  }) {
    return _sendStatus(
      path: ApiEndpoints.harnessAuthDisconnect,
      body: _accountPayload(harnessId: harnessId, accountId: accountId),
    );
  }

  Future<HarnessAuthStatus> _sendStatus({
    required String path,
    required Map<String, dynamic> body,
  }) {
    OnboardingLogger.event('harness auth request started', {'endpoint': path});
    return tryMethod(
      () async {
        final userId = _authRepo.currentUserId;
        if (userId == null || userId.isEmpty) {
          throw HarnessAuthException.notAuthenticated();
        }

        final response = await _pb.send<dynamic>(
          path,
          method: 'POST',
          body: body,
        );

        if (response is Map<String, dynamic>) {
          final status = HarnessAuthStatus.fromJson(response);
          OnboardingLogger.event('harness auth response received', {
            'endpoint': path,
            'status': status.status,
            'has_challenge': status.challenge != null,
          });
          return status;
        }

        throw HarnessAuthException('Unexpected response from auth endpoint');
      },
      HarnessAuthException.new,
      path,
    );
  }

  Map<String, dynamic> _accountPayload({
    required String harnessId,
    String? accountId,
    String? accountName,
    String? visibility,
    String? attemptId,
    String? credentialMode,
    String? provider,
    String? providerKey,
    String? code,
  }) {
    return {
      'harness': harnessId,
      if (accountId != null && accountId.isNotEmpty) 'accountId': accountId,
      if (accountName != null && accountName.isNotEmpty)
        'accountName': accountName,
      if (visibility != null) 'visibility': visibility,
      if (attemptId != null) 'attemptId': attemptId,
      if (credentialMode != null) 'credentialMode': credentialMode,
      if (provider != null) 'provider': provider,
      if (providerKey != null) 'providerKey': providerKey,
      if (code != null) 'code': code,
    };
  }
}
