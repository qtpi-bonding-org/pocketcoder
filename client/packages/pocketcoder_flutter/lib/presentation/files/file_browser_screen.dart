import 'package:flutter/material.dart';
import 'adapters/file_browser_adapter.dart';

class FileBrowserScreen extends StatelessWidget {
  final void Function(BuildContext context, String path) onOpenFile;

  const FileBrowserScreen({super.key, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    return FileBrowserAdapter(onOpenFile: onOpenFile);
  }
}
