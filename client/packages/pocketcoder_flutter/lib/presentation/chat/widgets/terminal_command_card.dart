import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// A read-only terminal transcript for a command Poco ran.
///
/// The command and lifecycle status are always visible. Output is deliberately
/// collapsed so a large tool result does not bury the conversation.
class TerminalCommandCard extends StatefulWidget {
  const TerminalCommandCard({
    super.key,
    required this.command,
    required this.status,
    required this.outputLabel,
    this.output,
    this.diffs = const [],
  });

  final String command;
  final Widget status;
  final String outputLabel;
  final String? output;
  final List<dynamic> diffs;

  @override
  State<TerminalCommandCard> createState() => _TerminalCommandCardState();
}

class _TerminalCommandCardState extends State<TerminalCommandCard> {
  bool _outputExpanded = false;

  bool get _hasOutput =>
      (widget.output?.isNotEmpty ?? false) || widget.diffs.isNotEmpty;

  String _prettyOutput(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return value;
      final textBlocks = <String>[];
      for (final block in decoded) {
        if (block is! Map ||
            block['type'] != 'text' ||
            block['text'] is! String) {
          return value;
        }
        textBlocks.add(block['text'] as String);
      }
      return textBlocks.join('\n');
    } on FormatException {
      return value;
    }
  }

  String _diffOutput(dynamic diff) {
    if (diff is! Map) return '';
    final path = diff['path'] as String? ?? '';
    final oldText = diff['oldText'] as String? ?? '';
    final newText = diff['newText'] as String? ?? '';
    final oldLines = oldText.isEmpty
        ? const <String>[]
        : oldText.split('\n').map((line) => '- $line');
    final newLines = newText.isEmpty
        ? const <String>[]
        : newText.split('\n').map((line) => '+ $line');
    return [path, ...oldLines, ...newLines].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final output =
        widget.output == null ? '' : _prettyOutput(widget.output ?? '');
    final diffOutput = widget.diffs
        .map(_diffOutput)
        .where((value) => value.isNotEmpty)
        .join('\n\n');
    final combinedOutput =
        [output, diffOutput].where((value) => value.isNotEmpty).join('\n\n');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.space * 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.status,
              HSpace.x1,
              Expanded(
                child: Text(
                  '\$ ${widget.command}',
                  style: TextStyle(
                    color: colors.secondary,
                    fontFamily: AppFonts.family,
                    fontWeight: AppFonts.heavy,
                    package: 'pocketcoder_flutter',
                  ),
                ),
              ),
            ],
          ),
          if (_hasOutput) ...[
            VSpace.x1,
            Semantics(
              button: true,
              label: widget.outputLabel,
              child: InkWell(
                onTap: () => setState(() => _outputExpanded = !_outputExpanded),
                child: Row(
                  children: [
                    Text(
                      // The glyph names the ACTION, not the state: collapsed
                      // offers `expand`, expanded offers `collapse`. It used
                      // to render `navigate` when collapsed, which is the
                      // one confusion RowAffordance exists to prevent.
                      (_outputExpanded
                              ? RowAffordance.collapse
                              : RowAffordance.expand)
                          .glyph,
                      style: TextStyle(
                        color: colors.secondary,
                        fontFamily: AppFonts.family,
                        fontWeight: AppFonts.heavy,
                      ),
                    ),
                    HSpace.x1,
                    Text(
                      widget.outputLabel,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.7),
                        fontFamily: AppFonts.family,
                        fontWeight: AppFonts.heavy,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_outputExpanded && combinedOutput.isNotEmpty) ...[
            VSpace.x1,
            SelectableText(
              combinedOutput,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.75),
                fontFamily: AppFonts.family,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
