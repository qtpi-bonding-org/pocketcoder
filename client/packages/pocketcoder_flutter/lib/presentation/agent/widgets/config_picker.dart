import 'package:acp_dart/acp_dart.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/searchable_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

class ConfigPicker extends StatelessWidget {
  const ConfigPicker(
      {super.key,
      required this.config,
      required this.onSetOption,
      this.onSearchModels});
  final Map<String, dynamic>? config;
  final void Function(SetSessionConfigOptionRequest request) onSetOption;
  final Future<List<HarnessModel>> Function()? onSearchModels;

  @override
  Widget build(BuildContext context) {
    final options = (config?['options'] as List?)
            ?.whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList() ??
        const <Map<String, dynamic>>[];
    if (options.isEmpty) return const SizedBox.shrink();
    // The model id is usually the longest value by far -- moving it to the
    // end lets the short options (provider/mode/thinking effort/...) share
    // a line instead of it splitting them across two.
    final ordered = [
      ...options.where((o) => o['id'] != 'model'),
      ...options.where((o) => o['id'] == 'model'),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.ch * 2,
        vertical: AppSizes.space * .5,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSizes.space,
        runSpacing: AppSizes.space * .25,
        children: [
          ...ordered.map((o) => _option(context, o)),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, Map<String, dynamic> o) {
    final id = o['id'] as String?;
    if (id == null) return const SizedBox.shrink();
    final name = (o['name'] as String?) ?? id,
        kind = o['kind'] as String?,
        value = o['currentValue'];
    void submit(String v) => onSetOption(
        SetSessionConfigOptionRequest(sessionId: '', configId: id, value: v));
    if (kind == 'boolean') {
      return ConfigOptionChip(
        label: name,
        value: value == true ? 'on' : 'off',
        onTap: () => submit('${value != true}'),
      );
    }
    if (kind == 'select' && id == 'model' && onSearchModels != null) {
      return _modelSearchChip(context,
          name: name, current: value?.toString(), submit: submit);
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
      return ConfigOptionChip(
          label: name,
          value: displayValue,
          affordance: RowAffordance.expand,
          maxValueChars: id == 'thinking_effort' ? 8 : null,
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
    return ConfigOptionChip(label: name, value: value?.toString() ?? '');
  }

  Widget _modelSearchChip(
    BuildContext context, {
    required String name,
    required String? current,
    required void Function(String) submit,
  }) =>
      ConfigOptionChip(
          label: name,
          value: switch (current) {
            null || '' => '--',
            final id => _afterSlash(id),
          },
          affordance: RowAffordance.expand,
          onTap: () async {
            final search = onSearchModels;
            if (search == null) return;
            final models = await search();
            if (!context.mounted) return;
            final selected = await showDialog<HarnessModel>(
                context: context,
                builder: (dialogContext) => SearchablePickerDialog<HarnessModel>(
                    title: name,
                    items: models,
                    itemLabel: (hm) => hm.harnessModelId,
                    itemBuilder: (context, hm,
                            {required isSelected, required onTap}) =>
                        InkWell(
                            onTap: onTap,
                            child: Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: AppSizes.space * .5),
                                child: TerminalText(hm.harnessModelId,
                                    role: isSelected
                                        ? TextRole.label
                                        : TextRole.body))),
                    selectedItem: models
                        .where((hm) => hm.harnessModelId == current)
                        .firstOrNull,
                    maxUnfilteredResults: 5,
                    searchLabel: dialogContext.l10n.providerScreenSearchLabel,
                    searchHint: dialogContext.l10n.agentModelSearchHint,
                    emptyLabel:
                        dialogContext.l10n.providerScreenNoHarnessModels,
                    noMatchesLabel: dialogContext.l10n.agentModelSearchNoMatches));
            if (selected != null) submit(selected.harnessModelId);
          });

  String _afterSlash(String harnessModelId) {
    final slash = harnessModelId.lastIndexOf('/');
    return slash < 0 ? harnessModelId : harnessModelId.substring(slash + 1);
  }
}

class ConfigOptionChip extends StatefulWidget {
  const ConfigOptionChip({
    super.key,
    required this.label,
    required this.value,
    this.affordance,
    this.onTap,
    this.maxValueChars,
  });

  final String label;
  final String? value;
  final RowAffordance? affordance;
  final VoidCallback? onTap;

  final int? maxValueChars;

  @override
  State<ConfigOptionChip> createState() => _ConfigOptionChipState();
}

class _ConfigOptionChipState extends State<ConfigOptionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reversed = _pressed;
    Widget text(String value, TextRole role,
        {int? maxLines, TextOverflow? overflow}) {
      final terminalText = TerminalText(value,
          role: role, maxLines: maxLines, overflow: overflow);
      if (!reversed) return terminalText;
      return ColorFiltered(
        colorFilter:
            const ColorFilter.mode(AppPalette.ground, BlendMode.srcIn),
        child: terminalText,
      );
    }

    final affordance = widget.affordance;
    final maxChars = widget.maxValueChars;
    final rawValue = widget.value ?? '';
    final valueWidget = maxChars == null || rawValue.length <= maxChars
        ? text(rawValue, TextRole.value)
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppSizes.ch * maxChars),
            child: text(rawValue, TextRole.value,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          );
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      valueWidget,
      if (affordance != null && affordance != RowAffordance.none) ...[
        SizedBox(width: AppSizes.space * .5),
        text(affordance.glyph, TextRole.value),
      ],
    ]);
    final onTap = widget.onTap;
    final chip = Container(
      color: reversed ? TextRole.value.color : Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * .5,
        vertical: AppSizes.space * .25,
      ),
      child: content,
    );
    return Semantics(
      label: widget.label,
      value: widget.value,
      child: onTap == null
          ? chip
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: chip,
            ),
    );
  }
}
