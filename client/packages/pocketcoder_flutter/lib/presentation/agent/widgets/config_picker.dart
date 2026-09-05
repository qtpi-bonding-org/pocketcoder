import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_checkbox.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_list_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

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
                        _expanded
                            ? RowAffordance.expand.glyph
                            : RowAffordance.collapse.glyph,
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
    final label = Text(name,
        style: TextStyle(
            color: context.colorScheme.onSurface, fontFamily: AppFonts.family));
    void submit(String v) => widget.onSetOption(
        SetSessionConfigOptionRequest(sessionId: '', configId: id, value: v));
    if (kind == 'boolean') {
      return Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.space * .5),
          child: Row(children: [
            Expanded(child: label),
            TerminalCheckbox(
                value: value == true, onChanged: (v) => submit('$v'))
          ]));
    }
    if (kind == 'select') {
      final choices = (o['options'] as List?)
              ?.whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList() ??
          const <Map<String, dynamic>>[];
      final current = value?.toString() ?? '';
      final displayValue = choices.any((c) => '${c['value']}' == current)
          ? current
          : (current.isEmpty ? '--' : current);
      return DetailRow(
          label: name,
          value: displayValue,
          affordance: RowAffordance.expand,
          onTap: () => showTerminalListPicker<String>(
                context: context,
                title: name,
                items: choices
                    .map((c) => '${c['value']}')
                    .toList(),
                itemBuilder: (_, item) => TerminalText(
                    (choices.firstWhere((c) => '${c['value']}' == item,
                            orElse: () => {})['label'] as String? ?? item),
                    role: TextRole.label),
                selected: displayValue == '--' ? null : current,
                emptyLabel: 'no options',
                cancelLabel: 'cancel',
              ).then((selected) {
                if (selected != null) submit(selected);
              }));
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
