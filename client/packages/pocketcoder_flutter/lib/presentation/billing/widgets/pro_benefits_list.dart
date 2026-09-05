import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ProBenefitsList extends StatelessWidget {
  const ProBenefitsList({super.key});

  @override
  Widget build(BuildContext context) {
    final benefits = [
      context.l10n.proBenefitServerSetup,
      context.l10n.proBenefitPushNotifications,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final benefit in benefits)
          Padding(
            padding: EdgeInsets.only(bottom: AppSizes.line * 0.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The service-line prefix (spec section 4), reused: dim marker,
                // body text. Replaces a hand-written '> ' that matched nothing.
                TerminalText('*', role: TextRole.label),
                SizedBox(width: AppSizes.ch),
                Expanded(
                  child: TerminalText(benefit, role: TextRole.body),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
