import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_palette.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_sizes.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// A sentence-case label and its value, with optional terminal affordances.
class DetailRow extends StatefulWidget {
  const DetailRow({
    super.key,
    required this.label,
    this.value,
    this.affordance,
    this.onTap,
    this.destructive = false,
    this.warning = false,
    this.hasBadge = false,
    this.isSelected = false,
    this.trailingDetail,
    this.trailing,
  })  : _kind = _DetailRowKind.row,
        _toggleValue = null,
        _onChanged = null,
        _controller = null,
        _inputChanged = null,
        _hint = null;

  const DetailRow.toggle({
    Key? key,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) : this._toggle(
          key: key,
          label: label,
          toggleValue: value,
          changed: onChanged,
        );

  const DetailRow.input({
    Key? key,
    required String label,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    String? hint,
  }) : this._input(
          key: key,
          label: label,
          controller: controller,
          changed: onChanged,
          hint: hint,
        );

  const DetailRow._toggle({
    super.key,
    required this.label,
    required bool toggleValue,
    required ValueChanged<bool> changed,
  })  : value = null,
        affordance = null,
        onTap = null,
        destructive = false,
        warning = false,
        hasBadge = false,
        isSelected = false,
        trailingDetail = null,
        trailing = null,
        _kind = _DetailRowKind.toggle,
        _toggleValue = toggleValue,
        _onChanged = changed,
        _controller = null,
        _inputChanged = null,
        _hint = null;

  const DetailRow._input({
    super.key,
    required this.label,
    TextEditingController? controller,
    ValueChanged<String>? changed,
    String? hint,
  })  : value = null,
        affordance = null,
        onTap = null,
        destructive = false,
        warning = false,
        hasBadge = false,
        isSelected = false,
        trailingDetail = null,
        trailing = null,
        _kind = _DetailRowKind.input,
        _toggleValue = null,
        _onChanged = null,
        _controller = controller,
        _inputChanged = changed,
        _hint = hint;

  final String label;
  final String? value;
  final RowAffordance? affordance;
  final VoidCallback? onTap;
  final bool destructive;
  final bool warning;
  final bool hasBadge;
  final bool isSelected;
  final String? trailingDetail;
  final Widget? trailing;

  final _DetailRowKind _kind;
  final bool? _toggleValue;
  final ValueChanged<bool>? _onChanged;
  final TextEditingController? _controller;
  final ValueChanged<String>? _inputChanged;
  final String? _hint;

  @override
  State<DetailRow> createState() => _DetailRowState();
}

enum _DetailRowKind { row, toggle, input }

class _DetailRowState extends State<DetailRow> {
  bool _pressed = false;
  TextEditingController? _ownedController;

  TextEditingController? get _controller =>
      widget._controller ?? _ownedController;

  @override
  void initState() {
    super.initState();
    if (widget._kind == _DetailRowKind.input && widget._controller == null) {
      _ownedController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  TextRole get _valueRole => widget.destructive
      ? TextRole.fail
      : (widget.warning ? TextRole.warn : TextRole.value);

  // Destructive/warning colours the whole row -- label included, not only
  // the value/affordance -- so the row reads as a unit rather than only its
  // trailing glyph carrying the meaning.
  TextRole get _labelRole => widget.destructive
      ? TextRole.fail
      : (widget.warning ? TextRole.warn : TextRole.label);

  bool get _reverseVideo => _pressed || widget.isSelected;

  Widget _text(String text, TextRole role) {
    if (!_reverseVideo) return TerminalText(text, role: role);
    // Keeps the semantic role; only the foreground swaps to ground.
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(AppPalette.ground, BlendMode.srcIn),
      child: TerminalText(text, role: role),
    );
  }

  Widget _label() => _text(widget.label.toLowerCase(), _labelRole);

  Widget _value(String text) => _text(text, _valueRole);

  Widget _badge() => _text('[!]', TextRole.warn);

  double _measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  bool _fits(BuildContext context, double width) {
    final inherited = DefaultTextStyle.of(context).style;
    final labelStyle = inherited.merge(_labelRole.style);
    final valueStyle = inherited.merge(_valueRole.style);
    var needed = _measure(widget.label.toLowerCase(), labelStyle);
    if (widget.hasBadge) {
      needed += AppSizes.ch + _measure('[!]', TextRole.warn.style);
    }
    final value = widget._kind == _DetailRowKind.toggle
        ? ((widget._toggleValue ?? false) ? 'on' : 'off')
        : widget.value;
    if (value != null) {
      needed += AppSizes.ch * 2 + _measure(value, valueStyle);
      if (widget.trailingDetail case final trailingDetail?) {
        needed += AppSizes.ch + _measure(trailingDetail, labelStyle);
      }
    }
    if (widget.affordance case final affordance?
        when affordance != RowAffordance.none) {
      needed += AppSizes.ch + _measure(affordance.glyph, valueStyle);
    }
    // `trailing` is an arbitrary widget we cannot measure via TextPainter.
    // A `<copy>`-style bracket button is the common case and is wider than
    // a couple of characters -- estimate generously so a real trailing
    // button doesn't get judged as fitting when it won't.
    if (widget.trailing != null) needed += AppSizes.ch * 8;
    return needed <= width;
  }

  Widget _input() => TextField(
        controller: _controller,
        onChanged: widget._inputChanged,
        style: _reverseVideo
            ? TextRole.value.style.copyWith(color: AppPalette.ground)
            : TextRole.value.style,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: widget._hint,
          hintStyle: TextRole.label.style,
        ),
      );

  Widget _valueAndExtras() {
    final value = widget._kind == _DetailRowKind.toggle
        ? ((widget._toggleValue ?? false) ? 'on' : 'off')
        : widget.value;
    final affordance = widget.affordance;
    final trailing = widget.trailing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null) Flexible(child: _value(value)),
        if (widget.trailingDetail case final trailingDetail?) ...[
          SizedBox(width: AppSizes.ch),
          _text(trailingDetail, TextRole.label),
        ],
        if (affordance != null && affordance != RowAffordance.none) ...[
          SizedBox(width: AppSizes.ch),
          _text(affordance.glyph, _valueRole),
        ],
        if (trailing != null) ...[
          SizedBox(width: AppSizes.ch),
          trailing,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - AppSizes.ch * 2;
          final oneLine = _fits(context, width);
          final content = oneLine
              ? widget._kind == _DetailRowKind.input
                  ? Row(children: [
                      _label(),
                      const Spacer(),
                      Flexible(child: _input()),
                    ])
                  : Row(children: [
                      _label(),
                      if (widget.hasBadge) ...[
                        SizedBox(width: AppSizes.ch),
                        _badge()
                      ],
                      const Spacer(),
                      _valueAndExtras(),
                    ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: _label()),
                    if (widget.hasBadge) ...[
                      SizedBox(width: AppSizes.ch),
                      _badge()
                    ],
                  ]),
                  Padding(
                    padding: EdgeInsets.only(left: AppSizes.ch * 2),
                    child: widget._kind == _DetailRowKind.input
                        ? _input()
                        : _valueAndExtras(),
                  ),
                ]);
          final row = Container(
            color: _reverseVideo ? _valueRole.color : Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: AppSizes.space),
            child: Padding(
              padding: EdgeInsets.only(left: AppSizes.ch * 2),
              child: content,
            ),
          );
          final onChanged = widget._onChanged;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget._kind == _DetailRowKind.toggle && onChanged != null
                ? () => onChanged(!(widget._toggleValue ?? false))
                : widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: row,
          );
        },
      );
}
