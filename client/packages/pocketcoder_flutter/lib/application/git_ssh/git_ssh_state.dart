import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/domain/models/git_ssh_credential.dart';

part 'git_ssh_state.freezed.dart';

@freezed
sealed class GitSshState with _$GitSshState, UiFlowStateMixin {
  const GitSshState._();

  const factory GitSshState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default([]) List<GitSshCredential> credentials,
    @Default([]) List<GitRepositoryAccess> access,
    Object? error,
  }) = _GitSshState;
}
