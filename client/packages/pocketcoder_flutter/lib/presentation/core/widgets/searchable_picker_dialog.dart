import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';

class SearchablePickerDialog<T> extends StatefulWidget {
  const SearchablePickerDialog(
      {super.key,
      required this.title,
      required this.items,
      required this.itemLabel,
      required this.itemBuilder,
      this.matches,
      this.groupLabel,
      this.selectedItem,
      this.searchLabel,
      this.searchHint,
      this.emptyLabel,
      this.noMatchesLabel});

  final String title;
  final List<T> items;
  final String Function(T item) itemLabel;
  final Widget Function(BuildContext context, T item,
      {required bool isSelected, required VoidCallback onTap}) itemBuilder;

  /// Defaults to a case-insensitive substring match on [itemLabel] when
  /// null. Kept independent of [itemLabel] so a caller can search a field
  /// it doesn't also want to sort/display by.
  final bool Function(T item, String query)? matches;

  final String Function(T item)? groupLabel;
  final T? selectedItem;
  final String? searchLabel;
  final String? searchHint;
  final String? emptyLabel;
  final String? noMatchesLabel;

  @override
  State<SearchablePickerDialog<T>> createState() =>
      _SearchablePickerDialogState<T>();
}

class _SearchablePickerDialogState<T> extends State<SearchablePickerDialog<T>> {
  final _searchController = TextEditingController();
  String _query = '';
  late List<T> _sortedItems;

  @override
  void initState() {
    super.initState();
    _sortedItems = _sortItems(widget.items);
  }

  @override
  void didUpdateWidget(SearchablePickerDialog<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items) ||
        oldWidget.groupLabel != widget.groupLabel) {
      _sortedItems = _sortItems(widget.items);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Sorted once here (not in _filtered) so typing into search never
  // re-sorts a large catalog on every keystroke.
  List<T> _sortItems(List<T> items) {
    final sorted = [...items];
    final group = widget.groupLabel;
    sorted.sort((a, b) {
      if (group != null) {
        final groupCompare = group(a).compareTo(group(b));
        if (groupCompare != 0) return groupCompare;
      }
      return widget.itemLabel(a).compareTo(widget.itemLabel(b));
    });
    return sorted;
  }

  List<T> get _filtered {
    if (_query.isEmpty) return _sortedItems;
    final matches = widget.matches ??
        (T item, String query) =>
            widget.itemLabel(item).toLowerCase().contains(query.toLowerCase());
    return _sortedItems.where((item) => matches(item, _query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final group = widget.groupLabel;
    final rows = <({String? header, T item})>[];
    String? previousGroup;
    for (final item in filtered) {
      final currentGroup = group?.call(item);
      final needsHeader =
          group != null && (rows.isEmpty || currentGroup != previousGroup);
      rows.add((header: needsHeader ? currentGroup : null, item: item));
      previousGroup = currentGroup;
    }

    return TerminalDialog(
        title: widget.title.toLowerCase(),
        content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: widget.items.isEmpty
                ? Center(
                    child: TerminalText(widget.emptyLabel ?? '',
                        role: TextRole.body))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        TerminalTextField(
                            controller: _searchController,
                            label: widget.searchLabel ?? '',
                            hint: widget.searchHint ?? '',
                            onChanged: (v) => setState(() => _query = v)),
                        const SizedBox(height: 8),
                        Expanded(
                            child: rows.isEmpty
                                ? Center(
                                    child: TerminalText(
                                    widget.noMatchesLabel ?? '',
                                    role: TextRole.label,
                                  ))
                                : ListView.builder(
                                    itemCount: rows.length,
                                    itemBuilder: (context, index) {
                                      final row = rows[index];
                                      final tile = widget.itemBuilder(
                                          context, row.item,
                                          isSelected: widget.selectedItem !=
                                                  null &&
                                              widget.selectedItem == row.item,
                                          onTap: () => Navigator.of(context)
                                              .pop(row.item));
                                      if (row.header == null) return tile;
                                      return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical:
                                                        AppSizes.space * 0.5),
                                                child: Text(
                                                    row.header!.toUpperCase(),
                                                    style: TextStyle(
                                                        fontFamily:
                                                            AppFonts.family,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                        fontWeight:
                                                            AppFonts.heavy,
                                                        package:
                                                            'pocketcoder_flutter'))),
                                            tile,
                                          ]);
                                    })),
                      ])),
        actions: [
          TerminalButton(
              label: context.l10n.actionCancel,
              isPrimary: false,
              onTap: () => Navigator.of(context).pop()),
        ]);
  }
}
