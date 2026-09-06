import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_checkbox.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/searchable_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

class ConfigPicker extends StatelessWidget {
  const ConfigPicker(
      {super.key, required this.config, required this.onSetOption});
  final Map<String, dynamic>? config;
  final void Function(SetSessionConfigOptionRequest request) onSetOption;

  @override
  Widget build(BuildContext context) {
    final options = (config?['options'] as List?)
            ?.whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList() ??
        const <Map<String, dynamic>>[];
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(label: context.l10n.agentSessionLabel),
      ...options.map((o) => _option(context, o)),
    ]);
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
    void submit(String v) => onSetOption(
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
      String labelFor(String value) =>
          choices.firstWhere((c) => '${c['value']}' == value,
              orElse: () => {})['label'] as String? ??
          value;
      return DetailRow(
          label: name,
          value: displayValue,
          affordance: RowAffordance.expand,
          onTap: () => showDialog<String>(
                context: context,
                builder: (_) => SearchablePickerDialog<String>(
                  title: name,
                  items: choices.map((c) => '${c['value']}').toList(),
                  itemLabel: labelFor,
                  selectedItem: displayValue == '--' ? null : current,
                  searchLabel: context.l10n.chatPickerSearchLabel,
                  searchHint: context.l10n.chatPickerSearchHint,
                  noMatchesLabel: context.l10n.chatPickerNoMatches,
                  itemBuilder: (_, item, {required isSelected, required onTap}) =>
                      InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: TerminalText(labelFor(item), role: TextRole.label),
                    ),
                  ),
                ),
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
