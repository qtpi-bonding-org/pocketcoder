import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// Keeps a fixed prompt prefix (e.g. "commander@pc $ ") as real text content,
/// not an overlay, so wrapped continuation lines return to the left margin
/// instead of hanging-indenting under the prompt.
class _PromptController extends TextEditingController {
  _PromptController({required String prompt}) : _prompt = prompt {
    text = _prompt;
  }

  final String _prompt;
  TextStyle promptStyle = const TextStyle();

  String get content =>
      text.length > _prompt.length ? text.substring(_prompt.length) : '';

  set content(String value) {
    text = _prompt + value;
    selection = TextSelection.collapsed(offset: text.length);
  }

  /// Re-stamps the prompt back onto the front of the text if an edit (e.g. a
  /// backspace at the prompt/content boundary, or a select-all paste) ate
  /// into it, recovering as much of the user's content as possible.
  void enforcePrompt() {
    if (text.startsWith(_prompt)) return;
    var keepFrom = 0;
    final limit = text.length < _prompt.length ? text.length : _prompt.length;
    while (keepFrom < limit && text[keepFrom] == _prompt[keepFrom]) {
      keepFrom++;
    }
    final remainder = text.length > keepFrom ? text.substring(keepFrom) : '';
    text = _prompt + remainder;
    selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final value = text;
    if (value.length <= _prompt.length) {
      return TextSpan(text: value, style: promptStyle);
    }
    return TextSpan(
      children: [
        TextSpan(text: value.substring(0, _prompt.length), style: promptStyle),
        TextSpan(text: value.substring(_prompt.length), style: style),
      ],
    );
  }
}

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
  late _PromptController _displayController;
  bool _syncing = false;

  String get _promptPrefix => '${widget.prompt} ';

  @override
  void initState() {
    super.initState();
    _startCursorBlink();
    _displayController = _PromptController(prompt: _promptPrefix)
      ..content = widget.controller.text;
    _displayController.addListener(_onDisplayChanged);
    widget.controller.addListener(_onExternalChanged);
  }

  @override
  void didUpdateWidget(covariant TerminalInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onExternalChanged);
      widget.controller.addListener(_onExternalChanged);
      _onExternalChanged();
    }
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    widget.controller.removeListener(_onExternalChanged);
    _displayController.removeListener(_onDisplayChanged);
    _displayController.dispose();
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

  void _onDisplayChanged() {
    if (_syncing) return;
    _displayController.enforcePrompt();
    if (widget.controller.text != _displayController.content) {
      _syncing = true;
      widget.controller.text = _displayController.content;
      _syncing = false;
    }
  }

  void _onExternalChanged() {
    if (_syncing) return;
    if (_displayController.content != widget.controller.text) {
      _syncing = true;
      _displayController.content = widget.controller.text;
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    _displayController.promptStyle = TextStyle(
      color: widget.enabled
          ? colors.secondary
          : colors.onSurface.withValues(alpha: 0.3),
      fontFamily: AppFonts.bodyFamily,
      package: 'pocketcoder_flutter',
      fontSize: AppSizes.fontStandard,
      fontWeight: AppFonts.heavy,
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.space,
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
      child: TextField(
        enabled: widget.enabled,
        controller: _displayController,
        focusNode: widget.focusNode,
        onSubmitted: (_) => widget.onSubmitted(),
        autofocus: true,
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.send,
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
    );
  }
}
