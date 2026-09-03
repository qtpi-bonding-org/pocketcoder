import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/files/widgets/file_browser_view.dart';

class FileBrowserAdapter extends CubitAdapter<FileBrowserCubit, FileBrowserState> {
  const FileBrowserAdapter({super.key, required this.onOpenFile});

  final void Function(BuildContext context, String path) onOpenFile;

  static FileBrowserState _selectState(FileBrowserState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<FileBrowserCubit, FileBrowserState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<FileBrowserCubit>();
    return UiFlowListener<FileBrowserCubit, FileBrowserState>(
      child: ValueListenableBuilder<FileBrowserState>(
        valueListenable: state,
        builder: (context, value, _) => FileBrowserView(
          state: value,
          onOpenFile: onOpenFile,
          onNavigateInto: cubit.navigateInto,
        ),
      ),
    );
  }
}
