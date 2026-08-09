import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/files/file_viewer_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'adapters/file_viewer_adapter.dart';

const _imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
const _maxPreviewBytes = 10 * 1024 * 1024;

class FileViewerScreen extends StatelessWidget {
  const FileViewerScreen({super.key, required this.path, required this.repository});

  final String path;
  final IFilesRepository repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => FileViewerCubit(repository)..load(path),
        child: FileViewerAdapter(path: path),
      );
}

class FileViewerView extends StatelessWidget {
  const FileViewerView({
    super.key,
    required this.path,
    required this.loading,
    required this.bytes,
    required this.error,
  });

  final String path;
  final bool loading;
  final Uint8List? bytes;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    return PocketCoderShell(
      title: path,
      activePillar: NavPillar.chats,
      showBack: true,
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) return const Center(child: TerminalLoadingIndicator());
    if (error != null) return Center(child: TerminalText('ERROR: $error', alpha: 0.8));
    final value = bytes;
    if (value == null) return const SizedBox.shrink();
    if (_imageExtensions.any(path.toLowerCase().endsWith)) {
      return Center(child: Image.memory(value));
    }
    if (value.length > _maxPreviewBytes) {
      return Center(child: TerminalText(context.l10n.filesTooLargeToPreview, alpha: 0.5));
    }
    try {
      return SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: SelectableText(
          utf8.decode(value),
          style: TextStyle(fontFamily: AppFonts.bodyFamily, fontSize: AppSizes.fontMini, package: 'pocketcoder_flutter'),
        ),
      );
    } on FormatException {
      return Center(child: TerminalText(context.l10n.filesCantPreviewType, alpha: 0.5));
    }
  }
}
