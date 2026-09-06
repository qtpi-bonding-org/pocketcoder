import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/files/file_viewer_cubit.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'adapters/file_viewer_adapter.dart';

class FileViewerScreen extends StatelessWidget {
  const FileViewerScreen(
      {super.key, required this.path, required this.repository});

  final String path;
  final IFilesRepository repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => FileViewerCubit(repository)..load(path),
        child: FileViewerAdapter(path: path),
      );
}
