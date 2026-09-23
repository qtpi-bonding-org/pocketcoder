import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class TerminalTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int maxLines;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final bool autocorrect;
  final bool enableSuggestions;
  final Iterable<String>? autofillHints;
  final bool revealable;

  const TerminalTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofillHints,
    this.revealable = false,
  });

  @override
  State<TerminalTextField> createState() => _TerminalTextFieldState();
}

class _TerminalTextFieldState extends State<TerminalTextField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final label = widget.label;
    final errorText = widget.errorText;
    final revealable = widget.obscureText && widget.revealable;
    final warningStyle = TextStyle(
      color: context.terminalColors.warning,
      fontFamily: AppFonts.family,
      package: 'pocketcoder_flutter',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toLowerCase(),
          style: TextStyle(
            fontFamily: AppFonts.family,
            color: colors.onSurface,
            fontWeight: AppFonts.heavy,
            package: 'pocketcoder_flutter',
          ),
        ),
        VSpace.x1,
        TextField(
          controller: widget.controller,
          obscureText: widget.obscureText && !_revealed,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          autocorrect: widget.autocorrect,
          enableSuggestions: widget.enableSuggestions,
          autofillHints: widget.autofillHints,
          style: TextStyle(
            fontFamily: AppFonts.family,
            package: 'pocketcoder_flutter',
            color: colors.onSurface,
          ),
          cursorColor: colors.onSurface,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.3),
              fontFamily: AppFonts.family,
              package: 'pocketcoder_flutter',
            ),
            fillColor: colors.surface,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.zero,
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: errorText != null
                    ? context.terminalColors.warning
                    : colors.onSurface,
              ),
              borderRadius: BorderRadius.zero,
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: context.terminalColors.warning),
              borderRadius: BorderRadius.zero,
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: context.terminalColors.warning),
              borderRadius: BorderRadius.zero,
            ),
            errorText: errorText,
            errorStyle: warningStyle,
            errorMaxLines: 3,
            helperText: widget.helperText,
            helperStyle: warningStyle,
            helperMaxLines: 3,
            suffixIcon: revealable
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _revealed = !_revealed),
                    child: Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.space * 2),
                        child: Text(
                          _revealed
                              ? context.l10n.terminalTextFieldHide
                              : context.l10n.terminalTextFieldShow,
                          style: TextStyle(
                            fontFamily: AppFonts.family,
                            package: 'pocketcoder_flutter',
                            color: colors.onSurface,
                            fontWeight: AppFonts.heavy,
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.all(AppSizes.space * 2),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
