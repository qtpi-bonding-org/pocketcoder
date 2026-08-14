import 'dart:typed_data';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'file_viewer_state.dart';

@injectable
class FileViewerCubit extends AppCubit<FileViewerState> {
  FileViewerCubit(this._repository) : super(const FileViewerState());

  final IFilesRepository _repository;

  Future<void> load(String path) async {
    await tryOperation(() async {
      final bytes = await _repository.readFile(path);
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        bytes: Uint8List.fromList(bytes),
      );
    }, emitLoading: true);
  }
}
