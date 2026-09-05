import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [children] out on one row at their natural width when they all
/// fit; otherwise splits them across the fewest rows that will hold them,
/// balanced evenly, with a trailing odd child centered alone. Unlike [Wrap],
/// a fallback never staggers into one item per line just because the full
/// row didn't fit.
class GridWrap extends MultiChildRenderObjectWidget {
  const GridWrap({
    super.key,
    required super.children,
    this.spacing = 0,
    this.runSpacing = 0,
    this.alignment = WrapAlignment.end,
  });

  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGridWrap(
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
      );

  @override
  void updateRenderObject(BuildContext context,
      // ignore: library_private_types_in_public_api
      covariant _RenderGridWrap renderObject) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..alignment = alignment;
  }
}

class _GridWrapParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderGridWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridWrapParentData> {
  _RenderGridWrap({
    required double spacing,
    required double runSpacing,
    required WrapAlignment alignment,
  })  : _spacing = spacing,
        _runSpacing = runSpacing,
        _alignment = alignment;

  double _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  WrapAlignment _alignment;
  set alignment(WrapAlignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridWrapParentData) {
      child.parentData = _GridWrapParentData();
    }
  }

  List<RenderBox> get _children {
    final list = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      list.add(child);
      child = (child.parentData as _GridWrapParentData).nextSibling;
    }
    return list;
  }

  double _rowStartX(double rowWidth, double maxWidth) => switch (_alignment) {
        WrapAlignment.end => (maxWidth - rowWidth).clamp(0.0, double.infinity),
        WrapAlignment.center =>
          ((maxWidth - rowWidth) / 2).clamp(0.0, double.infinity),
        _ => 0,
      };

  @override
  void performLayout() {
    final children = _children;
    if (children.isEmpty) {
      size = constraints.smallest;
      return;
    }

    final maxWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : double.infinity;

    final naturalSizes = [
      for (final child in children) child.getDryLayout(const BoxConstraints())
    ];
    final naturalRowWidth =
        naturalSizes.fold<double>(0, (sum, s) => sum + s.width) +
            _spacing * (children.length - 1);

    if (!maxWidth.isFinite || naturalRowWidth <= maxWidth) {
      double rowHeight = 0;
      for (var i = 0; i < children.length; i++) {
        children[i].layout(
          BoxConstraints.tight(naturalSizes[i]),
          parentUsesSize: true,
        );
        if (naturalSizes[i].height > rowHeight) rowHeight = naturalSizes[i].height;
      }
      final effectiveWidth = maxWidth.isFinite ? maxWidth : naturalRowWidth;
      var x = _rowStartX(naturalRowWidth, effectiveWidth);
      for (var i = 0; i < children.length; i++) {
        (children[i].parentData as _GridWrapParentData).offset =
            Offset(x, (rowHeight - naturalSizes[i].height) / 2);
        x += naturalSizes[i].width + _spacing;
      }
      size = constraints.constrain(Size(effectiveWidth, rowHeight));
      return;
    }

    // Use the fewest rows the content actually needs, then spread items
    // evenly across them. A fixed 2-column fallback turned five footer
    // items into three rows even though 3+2 fits in two.
    final rowCount = (naturalRowWidth / maxWidth).ceil().clamp(2, children.length);
    final columns = (children.length / rowCount).ceil();
    final rows = <List<int>>[
      for (var i = 0; i < children.length; i += columns)
        [
          for (var k = i; k < children.length && k < i + columns; k++) k,
        ],
    ];

    var y = 0.0;
    for (final row in rows) {
      var rowHeight = 0.0;
      for (final index in row) {
        children[index].layout(
          BoxConstraints(maxWidth: maxWidth),
          parentUsesSize: true,
        );
        if (children[index].size.height > rowHeight) {
          rowHeight = children[index].size.height;
        }
      }
      if (row.length > 1) {
        // Ends hug the edges, the rest spread evenly between -- the
        // <button1>   <button2>   <button3> spread. Positioning only the
        // first two left a third child stacked at the origin.
        final used = row.fold<double>(
            0, (sum, i) => sum + children[i].size.width);
        final slack =
            (maxWidth - used).clamp(0.0, double.infinity) / (row.length - 1);
        var x = 0.0;
        for (final index in row) {
          (children[index].parentData as _GridWrapParentData).offset =
              Offset(x, y + (rowHeight - children[index].size.height) / 2);
          x += children[index].size.width + slack;
        }
      } else {
        final index = row.first;
        final x = ((maxWidth - children[index].size.width) / 2)
            .clamp(0.0, double.infinity);
        (children[index].parentData as _GridWrapParentData).offset =
            Offset(x, y + (rowHeight - children[index].size.height) / 2);
      }
      y += rowHeight + _runSpacing;
    }
    if (rows.isNotEmpty) y -= _runSpacing;

    size = constraints.constrain(Size(maxWidth, y));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
