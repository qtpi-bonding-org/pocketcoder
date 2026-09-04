import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/pocketbase_inspector/pocketbase_inspector_cubit.dart';
import 'package:pocketcoder_flutter/application/pocketbase_inspector/pocketbase_inspector_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/pocketbase_inspector/i_pocketbase_inspector_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/pocketbase_inspector/widgets/pocketbase_inspector_view.dart';

class PocketbaseInspectorScreen extends StatefulWidget {
  const PocketbaseInspectorScreen({super.key});

  @override
  State<PocketbaseInspectorScreen> createState() =>
      _PocketbaseInspectorScreenState();
}

class _PocketbaseInspectorScreenState extends State<PocketbaseInspectorScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PocketbaseInspectorCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PocketbaseInspectorCubit, PocketbaseInspectorState>(
        builder: (context, state) => PocketCoderShell(
          title: context.l10n.pocketbaseInspectorTitle,
          activePillar: NavPillar.configure,
          showBack: true,
          body: switch (state.status) {
            UiFlowStatus.loading ||
            UiFlowStatus.idle =>
              const Center(child: TerminalLoadingIndicator()),
            UiFlowStatus.failure => Center(
                child: TerminalText(
                  context.l10n.pocketbaseInspectorUnavailable,
                  color: context.terminalColors.warning,
                ),
              ),
            UiFlowStatus.success => PocketbaseInspectorView(
                stats: state.stats ?? const PocketbaseInspectorStats(),
              ),
          },
        ),
      );
}
