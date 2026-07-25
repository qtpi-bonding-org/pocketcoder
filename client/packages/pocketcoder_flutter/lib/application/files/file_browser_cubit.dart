import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

@injectable
class FileBrowserCubit extends AppCubit<FileBrowserState> {
  final IFilesRepository _repository;

  FileBrowserCubit(this._repository) : super(FileBrowserState.initial());

  Future<void> open(String path) async {
    return tryOperation(() async {
      final entries = await _repository.listFiles(path);
      return createSuccessState().copyWith(path: path, entries: entries);
    });
  }

  Future<void> navigateInto(String name) async {
    final next = state.path.isEmpty ? name : '${state.path}/$name';
    await open(next);
  }

  Future<void> navigateUp() async {
    if (state.path.isEmpty) return;
    final segments = state.path.split('/')..removeLast();
    await open(segments.join('/'));
  }
}
