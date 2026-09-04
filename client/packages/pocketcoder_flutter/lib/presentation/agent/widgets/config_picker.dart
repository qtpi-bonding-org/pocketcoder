import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_checkbox.dart';

class ConfigPicker extends StatefulWidget {
  const ConfigPicker(
      {super.key, required this.config, required this.onSetOption});
  final Map<String, dynamic>? config;
  final void Function(SetSessionConfigOptionRequest request) onSetOption;
  @override
  State<ConfigPicker> createState() => _ConfigPickerState();
}

class _ConfigPickerState extends State<ConfigPicker> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final options = (config?['options'] as List?)
            ?.whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList() ??
        const <Map<String, dynamic>>[];
    if (options.isEmpty) return const SizedBox.shrink();
    final colors = context.colorScheme;
    return Container(
        padding: EdgeInsets.all(AppSizes.space),
        decoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: colors.onSurface.withValues(alpha: .1),
                    width: AppSizes.borderWidth))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.space * .5),
                  child: Row(children: [
                    Text(
                        _expanded ? RowAffordance.expand.glyph : RowAffordance.collapse.glyph,
                        style: TextStyle(
                            color: colors.onSurface.withValues(alpha: .5),
                            fontFamily: AppFonts.family)),
                    Text(context.l10n.agentConfigLabel,
                        style: TextStyle(
                            color: colors.onSurface.withValues(alpha: .5),
                            fontFamily: AppFonts.family,
                            fontWeight: AppFonts.heavy,
                            letterSpacing: 2))
                  ]))),
          if (_expanded) ...options.map((o) => _option(context, o)),
        ]));
  }

  Widget _option(BuildContext context, Map<String, dynamic> o) {
    final id = o['id'] as String?;
    if (id == null) return const SizedBox.shrink();
    final name = (o['name'] as String?) ?? id,
        kind = o['kind'] as String?,
        value = o['currentValue'];
    final label = Text(name.toUpperCase(),
        style: TextStyle(
            color: context.colorScheme.onSurface,
            fontFamily: AppFonts.family));
    void submit(String v) => widget.onSetOption(
        SetSessionConfigOptionRequest(sessionId: '', configId: id, value: v));
    if (kind == 'boolean') {
      return Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space * .5),
          child: Row(children: [
            Expanded(child: label),
            TerminalCheckbox(value: value == true, onChanged: (v) => submit('$v'))
          ]));
    }
    if (kind == 'select') {
      final choices = (o['options'] as List?)
              ?.whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList() ??
          const <Map<String, dynamic>>[];
      final current = value?.toString() ?? '';
      return Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space * .5),
          child: Row(children: [
            Expanded(child: label),
            DropdownButton<String>(
                value: choices.any((c) => '${c['value']}' == current)
                    ? current
                    : null,
                hint: Text(current.isEmpty ? '--' : current,
                    style: TextStyle(color: context.colorScheme.onSurface)),
                dropdownColor: context.colorScheme.surface,
                items: choices
                    .map((c) => DropdownMenuItem(
                        value: '${c['value']}',
                        child: Text((c['label'] as String? ?? '${c['value']}')
                            .toUpperCase())))
                    .toList(),
                onChanged: (v) {
                  if (v != null) submit(v);
                })
          ]));
    }
    return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space * .5),
        child: Row(children: [
          Expanded(child: label),
          Text(value?.toString() ?? '',
              style: TextStyle(
                  color: context.colorScheme.onSurface.withValues(alpha: .4)))
        ]));
  }
}
