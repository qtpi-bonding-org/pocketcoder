import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/memory/memory_cubit.dart';
import 'package:pocketcoder_flutter/application/memory/memory_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/memory/i_memory_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';

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
          title: 'POCKET MEMORY',
          activePillar: NavPillar.configure,
          showBack: true,
          body: switch (state.status) {
            UiFlowStatus.loading ||
            UiFlowStatus.idle =>
              const Center(child: TerminalLoadingIndicator()),
            UiFlowStatus.failure => Center(
                child: Text(
                  'MEMORY UNAVAILABLE',
                  style: TextStyle(color: context.terminalColors.warning),
                ),
              ),
            UiFlowStatus.success =>
              _MemoryContent(stats: state.stats ?? const MemoryStats()),
          },
        ),
      );
}

class _MemoryContent extends StatelessWidget {
  const _MemoryContent({required this.stats});

  final MemoryStats stats;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Row(
            children: [
              Expanded(
                  child: _CountCard(
                      label: 'OBSERVATIONS', value: stats.observations)),
              HSpace.x1,
              Expanded(
                  child: _CountCard(
                      label: 'INTERPRETATIONS',
                      value: stats.interpretations)),
              HSpace.x1,
              Expanded(child: _CountCard(label: 'LINKS', value: stats.links)),
            ],
          ),
          VSpace.x2,
          BiosSection(
            title: 'Memory by Account',
            child: stats.byAccount.isEmpty
                ? const _EmptyLabel('No memory recorded yet')
                : Column(
                    children: stats.byAccount
                        .map((account) => _AccountRow(account: account))
                        .toList(),
                  ),
          ),
          BiosSection(
            title: 'Recent Observations',
            child: stats.recentObservations.isEmpty
                ? const _EmptyLabel('No observations yet')
                : Column(
                    children: stats.recentObservations
                        .map((observation) => _ObservationRow(
                              observation: observation,
                            ))
                        .toList(),
                  ),
          ),
          BiosSection(
            title: 'Recent Interpretations',
            child: stats.recentInterpretations.isEmpty
                ? const _EmptyLabel('No interpretations yet')
                : Column(
                    children: stats.recentInterpretations
                        .map((interpretation) => _InterpretationRow(
                              interpretation: interpretation,
                            ))
                        .toList(),
                  ),
          ),
        ],
      );
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
          border: Border.all(color: context.colorScheme.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: context.colorScheme.primary,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontLarge,
                fontWeight: AppFonts.heavy,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: context.colorScheme.onSurface,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
        ),
      );
}

class _EmptyLabel extends StatelessWidget {
  const _EmptyLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Text(
          label,
          style: TextStyle(
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontSmall,
          ),
        ),
      );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final MemoryAccountSummary account;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space),
        child: Row(
          children: [
            Expanded(
              child: Text(
                account.agentName,
                style: TextStyle(
                  color: context.colorScheme.onSurface,
                  fontFamily: AppFonts.bodyFamily,
                ),
              ),
            ),
            Text(
              '${account.observations} obs / ${account.interpretations} int',
              style: TextStyle(
                color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontSmall,
              ),
            ),
          ],
        ),
      );
}

class _ObservationRow extends StatelessWidget {
  const _ObservationRow({required this.observation});

  final MemoryObservation observation;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${observation.author} · ${observation.createdAt}',
              style: TextStyle(
                color: context.colorScheme.primary,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
            Text(
              observation.body,
              style: TextStyle(
                color: context.colorScheme.onSurface,
                fontFamily: AppFonts.bodyFamily,
              ),
            ),
          ],
        ),
      );
}

class _InterpretationRow extends StatelessWidget {
  const _InterpretationRow({required this.interpretation});

  final MemoryInterpretation interpretation;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${interpretation.author} · ${interpretation.createdAt}',
              style: TextStyle(
                color: context.colorScheme.primary,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
            Text(
              interpretation.body,
              style: TextStyle(
                color: context.colorScheme.onSurface,
                fontFamily: AppFonts.bodyFamily,
              ),
            ),
            if (interpretation.linkedObservations.isNotEmpty)
              Text(
                'Linked: ${interpretation.linkedObservations.join(' | ')}',
                style: TextStyle(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontMini,
                ),
              ),
          ],
        ),
      );
}
