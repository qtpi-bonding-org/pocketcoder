// ElicitationCard: renders the pending SessionState.elicitation's
// requestedSchema as a flat form, now rendered inline in the message
// timeline (Builders.customMessageBuilder for metadata['kind'] ==
// 'elicitation') instead of as a standalone banner below the list.
// Renamed from presentation/agent/elicitation_form.dart's ElicitationForm --
// internals unchanged. Nested schema objects (oneOf, anyOf, arrays of
// objects) remain out of scope, same as before; URL-mode elicitations
// (mode == 'url') are also out of scope for this migration -- see the
// implementation plan's Global Constraints.
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';

class ElicitationCard extends StatefulWidget {
  const ElicitationCard({super.key, required this.item});

  final ElicitationRequestTimelineItem item;

  @override
  State<ElicitationCard> createState() => _ElicitationCardState();
}

class _ElicitationCardState extends State<ElicitationCard> {
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};
  String? _currentElicitationId;

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _textControllerFor(String field, String? initial) {
    return _textControllers.putIfAbsent(field, () {
      return TextEditingController(text: initial ?? '');
    });
  }

  void _resetForNewElicitation(String? elicitationId) {
    if (elicitationId == _currentElicitationId) return;
    for (final c in _textControllers.values) {
      c.clear();
    }
    _boolValues.clear();
    _currentElicitationId = elicitationId;
  }

  @override
  void initState() {
    super.initState();
    _resetForNewElicitation(widget.item.requestId);
  }

  @override
  void didUpdateWidget(covariant ElicitationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.requestId != widget.item.requestId) {
      _resetForNewElicitation(widget.item.requestId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.item.message;
    final properties =
        widget.item.schema?['properties'] as Map<String, dynamic>?;
    return _buildForm(context, message, properties);
  }

  Widget _buildForm(
    BuildContext context,
    String? message,
    Map<String, dynamic>? properties,
  ) {
    final colors = context.colorScheme;
    final terminalColors = context.terminalColors;

    final elicitationId = widget.item.requestId;
    final fields = properties?.entries.toList() ?? const [];

    return Container(
      margin: EdgeInsets.all(AppSizes.space),
      padding: EdgeInsets.all(AppSizes.space * 2),
      decoration: BoxDecoration(
        color: terminalColors.attention.withValues(alpha: 0.05),
        border: Border.all(
          color: terminalColors.attention.withValues(alpha: 0.3),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                color: terminalColors.attention,
                size: 20,
              ),
              HSpace.x2,
              Expanded(
                child: Text(
                  context.l10n.chatElicitationRequest,
                  style: TextStyle(
                    color: terminalColors.attention,
                    fontSize: AppSizes.fontTiny,
                    fontWeight: AppFonts.heavy,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          if (message != null && message.isNotEmpty) ...[
            VSpace.x2,
            Text(
              message,
              style: TextStyle(
                color: terminalColors.attention,
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontStandard,
              ),
            ),
          ],
          if (elicitationId.isNotEmpty) ...[
            VSpace.x1,
            Text(
              '[$elicitationId]',
              style: TextStyle(
                color: terminalColors.attention.withValues(alpha: 0.5),
                fontSize: AppSizes.fontMini,
              ),
            ),
          ],
          VSpace.x3,
          for (final entry in fields) ...[
            _buildField(
              context,
              name: entry.key,
              spec: entry.value is Map
                  ? Map<String, dynamic>.from(entry.value as Map)
                  : const <String, dynamic>{},
            ),
            VSpace.x2,
          ],
          if (fields.isEmpty)
            Text(
              context.l10n.chatNoFieldsRequested,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.4),
                fontSize: AppSizes.fontMini,
                fontStyle: FontStyle.italic,
              ),
            ),
          VSpace.x2,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: context.l10n.chatDecline,
                  isPrimary: false,
                  color: terminalColors.danger,
                  onTap: () => _submit(context, ElicitationResponse.decline()),
                ),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalButton(
                  label: context.l10n.actionCancel,
                  isPrimary: false,
                  onTap: () => _submit(context, ElicitationResponse.cancel()),
                ),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalButton(
                  label: context.l10n.chatSubmit,
                  onTap: () => _submit(
                    context,
                    ElicitationResponse.accept(_collectValues(properties)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required String name,
    required Map<String, dynamic> spec,
  }) {
    final colors = context.colorScheme;
    final type = spec['type'] as String?;
    final title = (spec['title'] as String?) ?? name;
    final initial = spec['currentValue'];

    switch (type) {
      case 'boolean':
        final value = _boolValues.putIfAbsent(
          name,
          () => initial is bool ? initial : false,
        );
        return Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) {
                setState(() => _boolValues[name] = v ?? false);
              },
            ),
            HSpace.x1,
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: AppFonts.bodyFamily,
                  fontSize: AppSizes.fontStandard,
                ),
              ),
            ),
          ],
        );
      case 'integer':
      case 'number':
        final controller = _textControllerFor(
          name,
          initial?.toString(),
        );
        return TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(
            labelText: title.toUpperCase(),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          style: TextStyle(
            color: colors.onSurface,
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontStandard,
          ),
        );
      case 'string':
      default:
        final controller = _textControllerFor(
          name,
          initial is String ? initial : null,
        );
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: title.toUpperCase(),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          style: TextStyle(
            color: colors.onSurface,
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontStandard,
          ),
        );
    }
  }

  Map<String, dynamic> _collectValues(Map<String, dynamic>? properties) {
    final out = <String, dynamic>{};
    if (properties == null) return out;
    for (final entry in properties.entries) {
      final spec = entry.value is Map
          ? Map<String, dynamic>.from(entry.value as Map)
          : const <String, dynamic>{};
      final type = spec['type'] as String?;
      switch (type) {
        case 'boolean':
          out[entry.key] = _boolValues[entry.key] ?? false;
        case 'integer':
          final text = _textControllers[entry.key]?.text ?? '';
          out[entry.key] = int.tryParse(text) ?? 0;
        case 'number':
          final text = _textControllers[entry.key]?.text ?? '';
          out[entry.key] = double.tryParse(text) ?? 0.0;
        case 'string':
        default:
          out[entry.key] = _textControllers[entry.key]?.text ?? '';
      }
    }
    return out;
  }

  void _submit(BuildContext context, ElicitationResponse resp) {
    _currentElicitationId = null;
    for (final c in _textControllers.values) {
      c.clear();
    }
    _boolValues.clear();
    context.read<ElicitationCubit>().submit(resp);
  }
}
