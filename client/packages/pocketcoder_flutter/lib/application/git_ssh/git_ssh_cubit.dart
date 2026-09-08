import 'dart:async';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/git_ssh/i_git_ssh_repository.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'git_ssh_state.dart';

@injectable
class GitSshCubit extends AppCubit<GitSshState> {
  final IGitSshRepository _repository;
  StreamSubscription? _credentialsSub;
  StreamSubscription? _accessSub;

  GitSshCubit(this._repository) : super(const GitSshState());

  @override
  Future<void> close() {
    _credentialsSub?.cancel();
    _accessSub?.cancel();
    return super.close();
  }

  void watch() {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _credentialsSub?.cancel();
    _accessSub?.cancel();
    _credentialsSub = _repository.watchCredentials().listen(
      (credentials) => emit(state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        credentials: credentials,
      )),
      onError: (e) => _handleError(e, 'watchCredentials'),
    );
    _accessSub = _repository.watchAccess().listen(
      (access) => emit(state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        access: access,
      )),
      onError: (e) => _handleError(e, 'watchAccess'),
    );
  }

  void _handleError(Object e, String operation) {
    unawaited(pocketCoderDiagnosticCapture.capture(
        error: e, source: 'GitSshCubit', operation: operation));
    logError('GitSsh: Failed to $operation', e);
    emit(state.copyWith(error: e, status: UiFlowStatus.failure));
  }

  Future<void> createAccountKey(String label) async {
    await tryOperation(() async {
      await _repository.createAccountKey(label);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> addRepositoryAccess({
    required GitRepositoryAccessProvider provider,
    required String repository,
    required String purpose,
    required GitRepositoryAccessCredentialMode credentialMode,
    required GitRepositoryAccessRequestedAccess requestedAccess,
    String? credential,
    String? host,
    int? port,
  }) async {
    await tryOperation(() async {
      await _repository.addRepositoryAccess(
        provider: provider,
        repository: repository,
        purpose: purpose,
        credentialMode: credentialMode,
        requestedAccess: requestedAccess,
        credential: credential,
        host: host,
        port: port,
      );
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> markRegistered(String accessId) async {
    await tryOperation(() async {
      await _repository.markRegistered(accessId);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }

  Future<void> deleteAccess(String accessId) async {
    await tryOperation(() async {
      await _repository.deleteAccess(accessId);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }
}
