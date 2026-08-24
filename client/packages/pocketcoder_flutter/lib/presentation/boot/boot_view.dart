import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';

class BootView extends StatelessWidget {
  const BootView({super.key, required this.logs, required this.logsDimmed, required this.pocoVisible, required this.pocoState, required this.scrollController});

  final List<String> logs;
  final bool logsDimmed;
  final bool pocoVisible;
  final PocoState pocoState;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: ScanlineWidget(
        child: Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(seconds: 1),
              opacity: logsDimmed ? 0.2 : 1.0,
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.all(AppSizes.space * 2),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final logEntry = logs[index];
                  Color? textColor = colors.primary;
                  if (logEntry.startsWith('[!]') || logEntry.contains('ERROR')) {
                    textColor = context.terminalColors.warning;
                  } else if (logEntry.startsWith('[sys]')) {
                    textColor = colors.tertiary;
                  } else if (logEntry.startsWith('[net]')) {
                    textColor = colors.secondary;
                  }
                  return Text(logEntry, style: context.textTheme.bodySmall?.copyWith(color: textColor));
                },
              ),
            ),
            if (pocoVisible)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: PocoBubble(message: pocoState.message, sequence: pocoState.sequence, history: pocoState.history, pocoSize: AppSizes.fontBig),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
