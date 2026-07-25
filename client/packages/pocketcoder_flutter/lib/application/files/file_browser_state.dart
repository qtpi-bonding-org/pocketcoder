import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';

part 'file_browser_state.freezed.dart';

@freezed
sealed class FileBrowserState with _$FileBrowserState implements IUiFlowState {
  const FileBrowserState._();

  const factory FileBrowserState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default('') String path,
    @Default([]) List<FileEntry> entries,
    Object? error,
  }) = _FileBrowserState;

  factory FileBrowserState.initial() => const FileBrowserState();

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
