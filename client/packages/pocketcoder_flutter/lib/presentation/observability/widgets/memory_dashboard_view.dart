import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/memory/i_memory_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/observability/widgets/count_card.dart';
import 'package:pocketcoder_flutter/presentation/observability/widgets/empty_label.dart';
import 'package:pocketcoder_flutter/presentation/observability/widgets/memory_record_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class MemoryDashboardView extends StatelessWidget {
  const MemoryDashboardView({super.key, required this.stats});

  final MemoryStats stats;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Row(
            children: [
              Expanded(
                  child: CountCard(
                      label: context.l10n.memoryDashboardObservations,
                      value: stats.observations)),
              HSpace.x1,
              Expanded(
                  child: CountCard(
                      label: context.l10n.memoryDashboardInterpretations,
                      value: stats.interpretations)),
              HSpace.x1,
              Expanded(
                  child: CountCard(
                      label: context.l10n.memoryDashboardLinks,
                      value: stats.links)),
            ],
          ),
          VSpace.x2,
          BiosSection(
            title: context.l10n.memoryDashboardByAccount,
            child: stats.byAccount.isEmpty
                ? EmptyLabel(context.l10n.memoryDashboardNoMemoryRecorded)
                : Column(
                    children: stats.byAccount
                        .map((account) => _AccountRow(account: account))
                        .toList(),
                  ),
          ),
          BiosSection(
            title: context.l10n.memoryDashboardRecentObservations,
            child: stats.recentObservations.isEmpty
                ? EmptyLabel(context.l10n.memoryDashboardNoObservationsYet)
                : Column(
                    children: stats.recentObservations
                        .map(
                          (observation) => MemoryRecordRow(
                            author: observation.author,
                            createdAt: observation.createdAt,
                            body: observation.body,
                          ),
                        )
                        .toList(),
                  ),
          ),
          BiosSection(
            title: context.l10n.memoryDashboardRecentInterpretations,
            child: stats.recentInterpretations.isEmpty
                ? EmptyLabel(context.l10n.memoryDashboardNoInterpretationsYet)
                : Column(
                    children: stats.recentInterpretations
                        .map(
                          (interpretation) => MemoryRecordRow(
                            author: interpretation.author,
                            createdAt: interpretation.createdAt,
                            body: interpretation.body,
                            linkedObservations:
                                interpretation.linkedObservations,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
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
              child: TerminalText(
                account.agentName,
                color: context.colorScheme.onSurface,
              ),
            ),
            TerminalText(
              context.l10n.memoryDashboardAccountSummary(
                  account.observations, account.interpretations),
              color: context.colorScheme.onSurface,
              alpha: 0.7,
            ),
          ],
        ),
      );
}
