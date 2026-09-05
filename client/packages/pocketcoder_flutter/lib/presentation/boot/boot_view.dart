import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/scanline_widget.dart';

/// The app's very first screen -- deliberately outside PocketCoderShell's/
/// TerminalScaffold's vocabulary, not an oversight. See the page-scaffold
/// plan (Task 9) for the
/// full reasoning: this runs before there is a session, a route to go
/// "back" to, or any NavPillar destination to show, and its full-bleed
/// animated-log-plus-overlay layout doesn't fit TerminalScaffold's
/// header/body/footer column model. If a future change gives this screen a
/// title, a back target, or footer actions, that's the signal to revisit
/// this decision -- until then, stays a raw Scaffold on purpose.
class BootView extends StatelessWidget {
  const BootView(
      {super.key,
      required this.logs,
      required this.logsDimmed,
      required this.pocoVisible,
      required this.pocoState,
      required this.scrollController});

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
                  if (logEntry.startsWith('[!]') ||
                      logEntry.contains('ERROR')) {
                    textColor = context.terminalColors.warning;
                  } else if (logEntry.startsWith('[sys]')) {
                    textColor = colors.tertiary;
                  } else if (logEntry.startsWith('[net]')) {
                    textColor = colors.secondary;
                  }
                  return Text(logEntry,
                      style: context.textTheme.bodySmall
                          ?.copyWith(color: textColor));
                },
              ),
            ),
            if (pocoVisible)
              Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Opaque backdrop so the dimmed log wall behind it
                      // doesn't bleed through the face glyph.
                      Center(
                        child: Container(
                          color: colors.surface,
                          child: PocoFace(
                            sequence: pocoState.sequence,
                            fontSize: 40.0,
                          ),
                        ),
                      ),
                      VSpace.x4,
                      PocoBubble(
                          message: pocoState.message,
                          history: pocoState.history,
                          showFace: false),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
