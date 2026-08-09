import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/files/file_viewer_cubit.dart';
import 'package:pocketcoder_flutter/presentation/files/file_viewer_screen.dart';

class FileViewerAdapter extends CubitAdapter<FileViewerCubit, FileViewerState> {
  const FileViewerAdapter({super.key, required this.path});

  final String path;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<FileViewerCubit, FileViewerState> adapter,
  ) {
    final state = adapter.cubitField((value) => value);
    return ValueListenableBuilder<FileViewerState>(
      valueListenable: state,
      builder: (context, value, _) => FileViewerView(
        path: path,
        loading: value.loading,
        bytes: value.bytes,
        error: value.error,
      ),
    );
  }
}
