import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';

class TerminalScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<TerminalAction>? actions;
  final Widget? floatingActionButton;
  final bool showHeader;
  final bool showFooter;
  final EdgeInsets? padding;

  const TerminalScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showHeader = true,
    this.showFooter = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: SafeArea(
          child: Column(
            children: [
              if (showHeader) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.space * 2),
                  child: TerminalHeader(title: title),
                ),
                VSpace.x1,
              ],
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
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: showFooter && actions != null
          ? TerminalFooter(actions: actions!)
          : null,
    );
  }
}
