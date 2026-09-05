import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

/// Renders the route-owned footer model into the common terminal chrome.
class ShellFooterView extends StatelessWidget {
  const ShellFooterView({super.key, required this.footer});
  final ShellFooter footer;

  static List<TerminalAction> actionsFor(ShellFooter footer,
          {bool configureBadge = false}) =>
      switch (footer) {
        PillarFooter footer => [
            for (final pillar in footer.available)
              TerminalAction(
                label: pillar.name,
                onTap: () => footer.onSelect(pillar),
                isActive: pillar == footer.active,
                hasBadge: pillar == NavPillar.config &&
                    (footer.configureBadge || configureBadge),
              ),
            ...footer.extraActions,
          ],
        WizardFooter footer => [
            if (footer.onBack != null)
              TerminalAction(label: 'back', onTap: footer.onBack!),
            TerminalAction(
              label: '(${footer.step}/${footer.totalSteps})',
              onTap: () {},
              isLabel: true,
            ),
            TerminalAction(label: 'next', onTap: footer.onNext),
          ],
        DeadEndFooter footer => [
            for (final action in footer.actions)
              TerminalAction(
                label: action.label,
                onTap: action.onTap,
                kind: action.kind,
              ),
          ],
      };

  @override
  Widget build(BuildContext context) =>
      TerminalFooter(actions: actionsFor(footer));
}
