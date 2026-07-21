// ConfigPicker (plan Task 13 Step 3): renders SessionState.config.options
// (a list of maps each with kind: 'boolean' | 'select', id, name,
// currentValue) and forwards changes through SessionControlsCubit.setOption
// with an ACP-shaped SetSessionConfigOptionRequest. The sessionId on the
// request is left as '' — the c1 up-channel is sessionId-elided (the
// request is scoped to the chat via the URL path, not the body — see plan
// Task 9).
//
// acp_dart 0.4.0's SetSessionConfigOptionRequest.value is a plain String,
// so booleans are serialized as "true"/"false".
import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class ConfigPicker extends StatelessWidget {
  const ConfigPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionControlsCubit, SessionControlsState>(
      builder: (context, state) {
        final config = state.config;
        if (config == null) return const SizedBox.shrink();

        final options = (config['options'] as List?)
                ?.whereType<Map>()
                .map((o) => Map<String, dynamic>.from(o))
                .toList() ??
            const <Map<String, dynamic>>[];
        if (options.isEmpty) return const SizedBox.shrink();

        return _buildList(context, options);
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Map<String, dynamic>> options,
  ) {
    final colors = context.colorScheme;
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.1),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: AppSizes.space),
            child: Text(
              'CONFIG',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontTiny,
                fontWeight: AppFonts.heavy,
                letterSpacing: 2,
              ),
            ),
          ),
          for (final option in options)
            _buildOptionRow(context, option),
        ],
      ),
    );
  }

  Widget _buildOptionRow(
    BuildContext context,
    Map<String, dynamic> option,
  ) {
    final id = option['id'] as String?;
    final name = (option['name'] as String?) ?? id ?? '';
    final kind = option['kind'] as String?;
    final currentValue = option['currentValue'];

    if (id == null) return const SizedBox.shrink();

    if (kind == 'boolean') {
      final enabled = currentValue == true;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: context.colorScheme.onSurface,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontStandard,
                ),
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (v) => _submit(
                context,
                id,
                v ? 'true' : 'false',
              ),
            ),
          ],
        ),
      );
    }

    if (kind == 'select') {
      final choices = (option['options'] as List?)
              ?.whereType<Map>()
              .map((o) => Map<String, dynamic>.from(o))
              .toList() ??
          const <Map<String, dynamic>>[];
      final current = currentValue?.toString() ?? '';
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name.toUpperCase(),
                style: TextStyle(
                  color: context.colorScheme.onSurface,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontStandard,
                ),
              ),
            ),
            DropdownButton<String>(
              value: choices.any((c) => '${c['value']}' == current)
                  ? current
                  : null,
              hint: Text(
                current.isEmpty ? '--' : current,
                style: TextStyle(
                  color: context.colorScheme.onSurface,
                  fontFamily: AppFonts.bodyFamily,
                ),
              ),
              dropdownColor: context.colorScheme.surface,
              items: choices
                  .map((c) => DropdownMenuItem<String>(
                        value: '${c['value']}',
                        child: Text(
                          (c['label'] as String? ?? '${c['value']}')
                              .toUpperCase(),
                          style: TextStyle(
                            color: context.colorScheme.onSurface,
                            fontFamily: AppFonts.bodyFamily,
                            fontSize: AppSizes.fontStandard,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) _submit(context, id, v);
              },
            ),
          ],
        ),
      );
    }

    // Unknown kind — render as a non-interactive label so the user still
    // sees what was published rather than silently dropping the option.
    final colors = context.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontStandard,
              ),
            ),
          ),
          Text(
            currentValue?.toString() ?? '',
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.4),
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontStandard,
            ),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context, String configId, String value) {
    context.read<SessionControlsCubit>().setOption(
          SetSessionConfigOptionRequest(
            sessionId: '',
            configId: configId,
            value: value,
          ),
        );
  }
}
