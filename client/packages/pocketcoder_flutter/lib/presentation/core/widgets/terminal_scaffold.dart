import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

class TerminalScaffold extends StatelessWidget {
  // No title param: screen titles belong in SectionHeader, rendered by the
  // screen's own body, not this chrome.
  final Widget body;
  final List<TerminalAction>? actions;

  /// A pre-built footer widget, used when the footer's layout can't be
  /// expressed as a flat [TerminalAction] row (e.g. a wizard's 3-slot
  /// back/counter/next layout). Takes precedence over [actions] when set.
  final Widget? footer;
  final bool showFooter;
  final EdgeInsets? padding;

  const TerminalScaffold({
    super.key,
    required this.body,
    this.actions,
    this.footer,
    this.showFooter = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final resolvedFooter = footer ??
        switch (actions) {
          final acts? => TerminalFooter(actions: acts),
          null => null,
        };
    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: padding ??
                      EdgeInsets.symmetric(horizontal: AppSizes.space * 2),
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: showFooter ? resolvedFooter : null,
    );
  }
}
