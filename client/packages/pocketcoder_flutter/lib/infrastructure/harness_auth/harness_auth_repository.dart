import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_exception.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

enum _HarnessAuthOperation { status, start, poll, submit, cancel, disconnect }

class HarnessAuthRepository implements IHarnessAuthRepository {
  HarnessAuthRepository(this._api, this._authRepo);

  final PocketCoderApiClient _api;
  final IAuthRepository _authRepo;

  @override
  Future<HarnessAuthStatus> status({
    required String harnessId,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      operation: _HarnessAuthOperation.status,
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
      operation: _HarnessAuthOperation.start,
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
      operation: _HarnessAuthOperation.poll,
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
      operation: _HarnessAuthOperation.submit,
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
      operation: _HarnessAuthOperation.cancel,
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
      operation: _HarnessAuthOperation.disconnect,
      body: _accountPayload(harnessId: harnessId, accountId: accountId),
    );
  }

  Future<HarnessAuthStatus> _sendStatus({
    required _HarnessAuthOperation operation,
    required Map<String, dynamic> body,
  }) {
    final operationName = operation.name;
    OnboardingLogger.event(
      'harness auth request started',
      {'operation': operationName},
    );
    return tryMethod(
      () async {
        final userId = _authRepo.currentUserId;
        if (userId == null || userId.isEmpty) {
          throw HarnessAuthException.notAuthenticated();
        }

        final requestBody = PocketCoderApiClient.encodeJson(body);
        final generatedResponse = switch (operation) {
          _HarnessAuthOperation.status =>
            await _api.harnessAuth.getHarnessAuthStatus(
              requestBody: requestBody,
            ),
          _HarnessAuthOperation.start =>
            await _api.harnessAuth.startHarnessAuth(requestBody: requestBody),
          _HarnessAuthOperation.poll =>
            await _api.harnessAuth.pollHarnessAuth(requestBody: requestBody),
          _HarnessAuthOperation.submit =>
            await _api.harnessAuth.submitHarnessAuth(requestBody: requestBody),
          _HarnessAuthOperation.cancel =>
            await _api.harnessAuth.cancelHarnessAuth(requestBody: requestBody),
          _HarnessAuthOperation.disconnect =>
            await _api.harnessAuth.disconnectHarnessAuth(
              requestBody: requestBody,
            ),
        };
        final response = PocketCoderApiClient.decodeJson(generatedResponse.data);

        final status = HarnessAuthStatus.fromJson(response);
        OnboardingLogger.event('harness auth response received', {
          'operation': operationName,
          'status': status.status,
          'has_challenge': status.challenge != null,
        });
        return status;
      },
      HarnessAuthException.new,
      operationName,
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
