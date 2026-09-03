import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ProBenefitsList extends StatelessWidget {
  const ProBenefitsList({super.key});

  @override
  Widget build(BuildContext context) {
    final benefits = [
      context.l10n.proBenefitServerSetup,
      context.l10n.proBenefitPushNotifications,
      context.l10n.proBenefitLiveMonitoring,
    ];
    return TerminalCard(
      padding: EdgeInsets.all(AppSizes.space * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final benefit in benefits)
            Padding(
              padding: EdgeInsets.only(bottom: AppSizes.space * 0.5),
              child: TerminalText.mini('> $benefit'),
            ),
        ],
      ),
    );
  }
}
