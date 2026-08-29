import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher(
      {super.key, required this.modes, required this.onSelectMode});
  final Map<String, dynamic>? modes;
  final ValueChanged<String> onSelectMode;

  @override
  Widget build(BuildContext context) {
    final available = (modes?['availableModes'] as List?)
            ?.whereType<Map>()
            .map(Map<String, dynamic>.from)
            .where((m) => m['id'] is String && (m['id'] as String).isNotEmpty)
            .toList() ??
        const <Map<String, dynamic>>[];
    if (available.isEmpty) return const SizedBox.shrink();
    final current = modes?['currentModeId'] as String?;
    final currentEntry = available.where((m) => m['id'] == current);
    final currentName = currentEntry.isEmpty
        ? (current ?? '')
        : ((currentEntry.first['name'] as String?) ?? current ?? '');
    final colors = context.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space * 2, vertical: AppSizes.space * .5),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: colors.onSurface.withValues(alpha: .1),
                  width: AppSizes.borderWidth))),
      child: Row(children: [
        Text(context.l10n.agentModeLabel,
            style: TextStyle(
                color: colors.onSurface.withValues(alpha: .5),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontTiny,
                fontWeight: AppFonts.heavy,
                letterSpacing: 2)),
        HSpace.x1,
        PopupMenuButton<String>(
          initialValue: current,
          onSelected: onSelectMode,
          itemBuilder: (context) => [
            for (final m in available)
              PopupMenuItem<String>(
                value: m['id'] as String,
                child: Text(
                  ((m['name'] as String?) ?? m['id'] as String).toUpperCase(),
                  style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      fontSize: AppSizes.fontMini,
                      fontWeight: AppFonts.heavy),
                ),
              ),
          ],
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(currentName.toUpperCase(),
                style: TextStyle(
                    color: colors.primary,
                    fontFamily: AppFonts.bodyFamily,
                    fontSize: AppSizes.fontMini,
                    fontWeight: AppFonts.heavy,
                    letterSpacing: 1)),
            HSpace.x1,
            Icon(Icons.arrow_drop_down,
                color: colors.primary, size: AppSizes.fontStandard),
          ]),
        ),
      ]),
    );
  }
}
