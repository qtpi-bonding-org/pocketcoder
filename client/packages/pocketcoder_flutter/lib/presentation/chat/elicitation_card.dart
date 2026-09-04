import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
// ElicitationCard renders a pending ACP form inline in the message timeline.
// It is Cubit-free: the adapter owns submission side effects and supplies the
// serialized response callback.
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/agent/elicitation_response.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_checkbox.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/tinted_alert_card.dart';

class ElicitationCard extends StatefulWidget {
  const ElicitationCard({
    super.key,
    required this.item,
    required this.onRespond,
  });

  final ElicitationRequestTimelineItem item;
  final void Function(String requestId, Map<String, dynamic> response)
      onRespond;

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

    final elicitationId = widget.item.requestId;
    final fields = properties?.entries.toList() ?? const [];

    return TintedAlertCard(
      eyebrowLeft: context.l10n.chatElicitationFormLabel,
      eyebrowRight: context.l10n.chatElicitationRequest,
      tint: colors.secondary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null && message.isNotEmpty)
            Text(
              message,
              style: TextStyle(
                color: colors.secondary,
                fontFamily: AppFonts.family,
              ),
            ),
          if (elicitationId.isNotEmpty) ...[
            VSpace.x1,
            Text(
              '[$elicitationId]',
              style: TextStyle(
                color: colors.secondary.withValues(alpha: 0.5),
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
                fontStyle: FontStyle.italic,
              ),
            ),
          VSpace.x2,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: context.l10n.actionCancel,
                  kind: ActionKind.neutral,
                  onTap: () => _submit(context, ElicitationResponse.cancel()),
                ),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalButton(
                  label: context.l10n.chatDecline,
                  kind: ActionKind.neutral,
                  onTap: () => _submit(context, ElicitationResponse.decline()),
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
            TerminalCheckbox(
              value: value,
              onChanged: (v) {
                setState(() => _boolValues[name] = v);
              },
            ),
            HSpace.x1,
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: AppFonts.family,
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
            fontFamily: AppFonts.family,
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
            fontFamily: AppFonts.family,
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
    widget.onRespond(widget.item.requestId, resp.toJson());
  }
}
