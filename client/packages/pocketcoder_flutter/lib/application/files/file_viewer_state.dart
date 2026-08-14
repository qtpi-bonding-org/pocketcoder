import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'file_viewer_state.freezed.dart';

@freezed
sealed class FileViewerState with _$FileViewerState, UiFlowStateMixin {
  const FileViewerState._();

  const factory FileViewerState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Uint8List? bytes,
    Object? error,
  }) = _FileViewerState;
}
