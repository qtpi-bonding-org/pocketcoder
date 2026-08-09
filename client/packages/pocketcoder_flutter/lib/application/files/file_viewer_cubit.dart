import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';

class FileViewerState {
  const FileViewerState({
    this.loading = true,
    this.bytes,
    this.error,
  });

  final bool loading;
  final Uint8List? bytes;
  final Object? error;
}

@injectable
class FileViewerCubit extends Cubit<FileViewerState> {
  FileViewerCubit(this._repository) : super(const FileViewerState());

  final IFilesRepository _repository;

  Future<void> load(String path) async {
    emit(const FileViewerState());
    try {
      final bytes = await _repository.readFile(path);
      if (!isClosed) emit(FileViewerState(bytes: Uint8List.fromList(bytes), loading: false));
    } catch (error) {
      if (!isClosed) emit(FileViewerState(error: error, loading: false));
    }
  }
}
