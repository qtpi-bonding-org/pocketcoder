import 'package:injectable/injectable.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_exception.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';
import 'package:pocketcoder_flutter/domain/models/credential_selection.dart';
import 'package:pocketcoder_flutter/domain/models/harness_oauth_account.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_account_daos.dart';

enum _HarnessAuthOperation { status, start, poll, submit, cancel, disconnect }

@LazySingleton(as: IHarnessAuthRepository)
class HarnessAuthRepository implements IHarnessAuthRepository {
  HarnessAuthRepository(this._api, this._authRepo,
      [this._oauthAccountDao, this._credentialSelectionDao]);

  final PocketCoderApiClient _api;
  final IAuthRepository _authRepo;
  final HarnessOAuthAccountDao? _oauthAccountDao;
  final CredentialSelectionDao? _credentialSelectionDao;

  @override
  Stream<List<HarnessOauthAccount>> watchHarnessOAuthAccounts() =>
      _oauthAccountDao!.watch();

  @override
  Stream<List<CredentialSelection>> watchCredentialSelections() =>
      _credentialSelectionDao!.watch();

  @override
  Future<HarnessAuthStatus> status({
    required String harnessId,
    required String provider,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      operation: _HarnessAuthOperation.status,
      request: _request(
        harnessId: harnessId,
        provider: provider,
        accountId: accountId,
        attemptId: attemptId,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> start({
    required String harnessId,
    required String provider,
    required String mode,
    required String visibility,
    String? accountId,
    String? accountName,
  }) {
    return _sendStatus(
      operation: _HarnessAuthOperation.start,
      request: _request(
        harnessId: harnessId,
        provider: provider,
        accountId: accountId,
        accountName: accountName,
        visibility: visibility,
        mode: mode,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> poll({
    required String harnessId,
    required String provider,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      operation: _HarnessAuthOperation.poll,
      request: _request(
        harnessId: harnessId,
        provider: provider,
        accountId: accountId,
        attemptId: attemptId,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> submit({
    required String harnessId,
    required String provider,
    required String code,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      operation: _HarnessAuthOperation.submit,
      request: _request(
        harnessId: harnessId,
        provider: provider,
        accountId: accountId,
        attemptId: attemptId,
        code: code,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> cancel({
    required String harnessId,
    required String provider,
    String? accountId,
    String? attemptId,
  }) {
    return _sendStatus(
      operation: _HarnessAuthOperation.cancel,
      request: _request(
        harnessId: harnessId,
        provider: provider,
        accountId: accountId,
        attemptId: attemptId,
      ),
    );
  }

  @override
  Future<HarnessAuthStatus> disconnect({
    required String harnessId,
    required String provider,
    String? accountId,
  }) {
    return _sendStatus(
      operation: _HarnessAuthOperation.disconnect,
      request: _request(
        harnessId: harnessId,
        provider: provider,
        accountId: accountId,
      ),
    );
  }

  /// Builds the strongly-typed generated request -- every field name and the
  /// mode enum's values (oauth|none) are enforced at compile time by
  /// pocketcoder_api, generated from api/openapi/pocketcoder.yaml. This is
  /// deliberately NOT a hand-built `Map<String, dynamic>`: a raw map would let
  /// this repository silently drift from the server's actual wire contract
  /// (as happened previously, see the harness-provider schema redesign
  /// plan's Task 14 commit notes) with no compiler check catching it.
  generated.HarnessRequest _request({
    required String harnessId,
    required String provider,
    String? accountId,
    String? accountName,
    String? visibility,
    String? attemptId,
    String? mode,
    String? code,
  }) {
    return generated.HarnessRequest((b) {
      b.harness = harnessId;
      b.provider = provider;
      if (accountId != null && accountId.isNotEmpty) b.accountId = accountId;
      if (accountName != null && accountName.isNotEmpty) {
        b.accountName = accountName;
      }
      if (visibility != null) b.visibility = visibility;
      if (attemptId != null) b.attemptId = attemptId;
      if (mode != null) {
        b.mode = generated.HarnessRequestModeEnum.valueOf(mode);
      }
      if (code != null) b.code = code;
    });
  }

  Future<HarnessAuthStatus> _sendStatus({
    required _HarnessAuthOperation operation,
    required generated.HarnessRequest request,
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

        final response = switch (operation) {
          _HarnessAuthOperation.status =>
            await _api.harnessAuth.getHarnessAuthStatus(harnessRequest: request),
          _HarnessAuthOperation.start =>
            await _api.harnessAuth.startHarnessAuth(harnessRequest: request),
          _HarnessAuthOperation.poll =>
            await _api.harnessAuth.pollHarnessAuth(harnessRequest: request),
          _HarnessAuthOperation.submit =>
            await _api.harnessAuth.submitHarnessAuth(harnessRequest: request),
          _HarnessAuthOperation.cancel =>
            await _api.harnessAuth.cancelHarnessAuth(harnessRequest: request),
          _HarnessAuthOperation.disconnect =>
            await _api.harnessAuth.disconnectHarnessAuth(harnessRequest: request),
        };
        final generated = response.data;
        if (generated == null) {
          throw HarnessAuthException('Empty harness auth response');
        }

        final status = _toDomain(generated);
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

  HarnessAuthStatus _toDomain(generated.HarnessAuthStatus g) {
    final attempt = g.attempt;
    final challenge = g.challenge;
    return HarnessAuthStatus(
      harness: g.harness,
      provider: g.provider,
      accountId: g.accountId ?? '',
      accountName: g.accountName ?? '',
      visibility: g.visibility ?? harnessAccountVisibilityPersonal,
      credentialMode: g.mode.name,
      status: g.status,
      lastError: g.lastError,
      attempt: attempt == null
          ? null
          : HarnessAuthAttempt(
              id: attempt.id,
              provider: '',
              status: attempt.status,
              lastError: attempt.lastError,
            ),
      challenge: challenge == null
          ? null
          : HarnessAuthChallenge.fromJson({
              'type': challenge.type,
              'text': challenge.text,
              'target': challenge.target,
              'details': challenge.details,
            }),
    );
  }
}
