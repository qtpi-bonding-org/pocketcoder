import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/memory/i_memory_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/observability/widgets/empty_label.dart';
import 'package:pocketcoder_flutter/presentation/observability/widgets/memory_record_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class MemoryDashboardView extends StatelessWidget {
  const MemoryDashboardView({super.key, required this.stats});

  final MemoryStats stats;

  @override
  Widget build(BuildContext context) => ListView(children: [
        SectionHeader(name: 'memory'),
        DetailRow(
          label: context.l10n.memoryDashboardObservations.toLowerCase(),
          value: '${stats.observations}',
        ),
        DetailRow(
          label: context.l10n.memoryDashboardInterpretations.toLowerCase(),
          value: '${stats.interpretations}',
        ),
        DetailRow(
          label: context.l10n.memoryDashboardLinks.toLowerCase(),
          value: '${stats.links}',
        ),
        VSpace.x2,
        SectionHeader(
            name: context.l10n.memoryDashboardByAccount.toLowerCase()),
        stats.byAccount.isEmpty
            ? EmptyLabel(context.l10n.memoryDashboardNoMemoryRecorded)
            : Column(
                children: stats.byAccount
                    .map((account) => _AccountRow(account: account))
                    .toList()),
        VSpace.x2,
        SectionHeader(
            name: context.l10n.memoryDashboardRecentObservations.toLowerCase()),
        stats.recentObservations.isEmpty
            ? EmptyLabel(context.l10n.memoryDashboardNoObservationsYet)
            : Column(
                children: stats.recentObservations
                    .map((observation) => MemoryRecordRow(
                        author: observation.author,
                        createdAt: observation.createdAt,
                        body: observation.body))
                    .toList()),
        VSpace.x2,
        SectionHeader(
            name: context.l10n.memoryDashboardRecentInterpretations
                .toLowerCase()),
        stats.recentInterpretations.isEmpty
            ? EmptyLabel(context.l10n.memoryDashboardNoInterpretationsYet)
            : Column(
                children: stats.recentInterpretations
                    .map((interpretation) => MemoryRecordRow(
                        author: interpretation.author,
                        createdAt: interpretation.createdAt,
                        body: interpretation.body,
                        linkedObservations: interpretation.linkedObservations))
                    .toList()),
      ]);
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final MemoryAccountSummary account;

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: AppSizes.space),
      child: Row(children: [
        Expanded(
          child: TerminalText(
            account.agentName,
            role: TextRole.body,
          ),
        ),
        TerminalText(
          context.l10n.memoryDashboardAccountSummary(
              account.observations, account.interpretations),
          role: TextRole.body,
        ),
      ]));
}
