import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/memory/memory_cubit.dart';
import 'package:pocketcoder_flutter/application/memory/memory_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/memory/i_memory_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/observability/widgets/memory_dashboard_view.dart';

class MemoryDashboardScreen extends StatefulWidget {
  const MemoryDashboardScreen({super.key});

  @override
  State<MemoryDashboardScreen> createState() => _MemoryDashboardScreenState();
}

class _MemoryDashboardScreenState extends State<MemoryDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MemoryCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<MemoryCubit, MemoryState>(
      builder: (context, state) => PocketCoderShell(
          footer: buildPillarFooter(context, NavPillar.status),
          showBack: true,
          body: switch (state.status) {
            UiFlowStatus.loading ||
            UiFlowStatus.idle =>
              const Center(child: TerminalLoadingIndicator()),
            UiFlowStatus.failure => Center(
                child: TerminalText(context.l10n.memoryDashboardUnavailable,
                    role: TextRole.warn)),
            UiFlowStatus.success =>
              MemoryDashboardView(stats: state.stats ?? const MemoryStats())
          }));
}
