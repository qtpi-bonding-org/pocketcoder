import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'file_viewer_body.dart';

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
    final body = FileViewerBody(
      path: path,
      loading: loading,
      bytes: bytes,
      error: error,
    );
    return PocketCoderShell(
      footer: buildPillarFooter(context, NavPillar.chat),
      showBack: true,
      body: body,
    );
  }
}
