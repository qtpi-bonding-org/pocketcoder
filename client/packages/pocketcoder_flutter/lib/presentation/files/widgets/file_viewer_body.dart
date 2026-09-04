import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

const _imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
const _maxPreviewBytes = 10 * 1024 * 1024;

class FileViewerBody extends StatelessWidget {
  const FileViewerBody({
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
    if (loading) return const Center(child: TerminalLoadingIndicator());
    if (error != null) {
      return Center(
          child: TerminalText(safeErrorMessage(error),
              alpha: 0.8));
    }
    final value = bytes;
    if (value == null) return const SizedBox.shrink();
    if (_imageExtensions.any(path.toLowerCase().endsWith)) {
      return Center(child: Image.memory(value));
    }
    if (value.length > _maxPreviewBytes) {
      return Center(
          child: TerminalText(context.l10n.filesTooLargeToPreview, alpha: 0.5));
    }
    try {
      return SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: SelectableText(
          utf8.decode(value),
          style: TextStyle(
              fontFamily: AppFonts.family,
              package: 'pocketcoder_flutter'),
        ),
      );
    } on FormatException {
      return Center(
          child: TerminalText(context.l10n.filesCantPreviewType, alpha: 0.5));
    }
  }
}
