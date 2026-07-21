// ModeSwitcher (plan Task 13 Step 3): renders SessionState.modes (current
// mode + list of available modes), lets the user pick a mode, and forwards
// the selection via SessionControlsCubit.selectMode. Renders nothing when
// no modes map is published yet.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionControlsCubit, SessionControlsState>(
      builder: (context, state) {
        final modes = state.modes;
        if (modes == null) return const SizedBox.shrink();

        final available = (modes['availableModes'] as List?)
                ?.whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList() ??
            const <Map<String, dynamic>>[];
        if (available.isEmpty) return const SizedBox.shrink();

        final current = modes['currentModeId'] as String?;

        return _buildRow(context, available, current);
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<Map<String, dynamic>> available,
    String? current,
  ) {
    final colors = context.colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space * 0.5,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.1),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'MODE:',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontTiny,
              fontWeight: AppFonts.heavy,
              letterSpacing: 2,
            ),
          ),
          HSpace.x1,
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: available.map((m) {
                  final id = m['id'] as String?;
                  final name = (m['name'] as String?) ?? id ?? '';
                  final isSelected = id != null && id == current;
                  return Padding(
                    padding: EdgeInsets.only(right: AppSizes.space),
                    child: _ModeChip(
                      label: name.toUpperCase(),
                      isSelected: isSelected,
                      onTap: id == null
                          ? null
                          : () => context
                              .read<SessionControlsCubit>()
                              .selectMode(id),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ModeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.space * 1.5,
          vertical: AppSizes.space * 0.5,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.3),
            width: AppSizes.borderWidth,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colors.primary : colors.onSurface,
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontMini,
            fontWeight: AppFonts.heavy,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
