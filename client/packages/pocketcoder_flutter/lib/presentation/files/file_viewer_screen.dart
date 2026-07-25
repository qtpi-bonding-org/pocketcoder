import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

const _imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];
const _maxPreviewBytes = 10 * 1024 * 1024; // 10 MB

class FileViewerScreen extends StatefulWidget {
  final String path;
  final IFilesRepository repository;

  const FileViewerScreen({super.key, required this.path, required this.repository});

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _loading = true;
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.repository.readFile(widget.path);
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool get _isImage {
    final lower = widget.path.toLowerCase();
    return _imageExtensions.any(lower.endsWith);
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: widget.path,
      activePillar: NavPillar.chats,
      showBack: true,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: TerminalLoadingIndicator());
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: TerminalText('ERROR: $error', alpha: 0.8),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return const SizedBox.shrink();
    }
    if (_isImage) {
      return Center(child: Image.memory(bytes));
    }
    if (bytes.length > _maxPreviewBytes) {
      return Center(
        child: TerminalText(context.l10n.filesTooLargeToPreview, alpha: 0.5),
      );
    }
    try {
      final text = utf8.decode(bytes);
      return SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: SelectableText(
          text,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontMini,
            package: 'pocketcoder_flutter',
          ),
        ),
      );
    } on FormatException {
      return Center(
        child: TerminalText(context.l10n.filesCantPreviewType, alpha: 0.5),
      );
    }
  }
}
