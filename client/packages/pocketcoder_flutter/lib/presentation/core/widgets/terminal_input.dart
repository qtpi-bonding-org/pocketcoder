import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class TerminalInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String prompt;
  final bool enabled;
  final FocusNode? focusNode;

  const TerminalInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.prompt = '%',
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<TerminalInput> createState() => _TerminalInputState();
}

class _TerminalInputState extends State<TerminalInput> {
  bool _cursorVisible = true;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _startCursorBlink();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    super.dispose();
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          _cursorVisible = !_cursorVisible;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space * 2,
        vertical: AppSizes.space * 1.5,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.2),
            width: AppSizes.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              '${widget.prompt} ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.enabled
                    ? colors.secondary
                    : colors.onSurface.withValues(alpha: 0.3),
                fontFamily: AppFonts.bodyFamily,
                package: 'pocketcoder_flutter',
                fontSize: AppSizes.fontStandard,
                fontWeight: AppFonts.heavy,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              enabled: widget.enabled,
              controller: widget.controller,
              focusNode: widget.focusNode,
              onSubmitted: (_) => widget.onSubmitted(),
              autofocus: true,
              style: TextStyle(
                color: colors.secondary,
                fontFamily: AppFonts.bodyFamily,
                package: 'pocketcoder_flutter',
                fontSize: AppSizes.fontStandard,
              ),
              // We simulate the terminal block cursor by using a custom color toggle
              // and a wider cursor width.
              cursorColor: _cursorVisible && widget.enabled
                  ? colors.secondary
                  : colors.surface.withValues(alpha: 0),
              cursorWidth: 10,
              cursorHeight: AppSizes.fontStandard,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
