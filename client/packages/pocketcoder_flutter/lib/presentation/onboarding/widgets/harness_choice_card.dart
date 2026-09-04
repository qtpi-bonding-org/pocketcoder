import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/glyph_label_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class HarnessChoiceCard extends StatelessWidget {
  const HarnessChoiceCard({
    super.key,
    required this.harness,
    required this.connected,
    required this.onTap});

  final Harnesse harness;
  final bool connected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Opacity(
      key: ValueKey('harness-card-opacity-${harness.cliId}'),
      opacity: onTap == null ? 0.4 : 1.0,
      child: IgnorePointer(
        ignoring: onTap == null,
        child: InkWell(
          onTap: onTap,
          child: TerminalCard(
            child: Row(
              children: [
                Expanded(
                  child: GlyphLabelRow(
                    glyph: r'$',
                    spacing: HSpace.x2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          harness.name,
                          style: TextStyle(
                            ,
                            fontFamily: AppFonts.family,
                            fontWeight: AppFonts.heavy)),
                        VSpace.x1,
                        TerminalText(
                          connected
                              ? context.l10n.onboardingConnected
                              : switch (harness.cliId.trim().toLowerCase()) {
                                  'codex' =>
                                    context.l10n.onboardingCodexAccountLogin,
                                  'claude-code' =>
                                    context.l10n.onboardingClaudeAccountLogin,
                                  _ => context.l10n
                                      .onboardingHarnessAccountLogin(
                                          harness.name)},
                          ),
                      ]))),
                TerminalText(
                  connected ? '[x]' : '[>]'),
              ])))));
  }
}
