import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_checkbox.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// A vertical list of mutually-exclusive `[x]`/`[ ]` options -- for a
/// single-select choice among a handful of named alternatives (a provider,
/// a credential, a frequency). Not a button row: these are picking one of
/// several states, not firing an action.
class TerminalChoiceList<T> extends StatelessWidget {
  const TerminalChoiceList({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options
          .map((entry) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(entry.$1),
                child: Row(children: [
                  TerminalCheckbox(
                    value: value == entry.$1,
                    onChanged: (_) => onSelected(entry.$1),
                  ),
                  HSpace.x2,
                  Expanded(
                    child: TerminalText(entry.$2, role: TextRole.body),
                  ),
                ]),
              ))
          .toList(),
    );
  }
}

/// A vertical list of independent `[x]`/`[ ]` toggles -- for a multi-select
/// choice among a handful of named alternatives (days of the week, tags).
class TerminalMultiChoiceList<T> extends StatelessWidget {
  const TerminalMultiChoiceList({
    super.key,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final Set<T> selected;
  final List<(T, String)> options;

  /// Called with the full updated selection set when one option is toggled.
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((entry) {
        final isSelected = selected.contains(entry.$1);
        void toggle() {
          final next = Set<T>.of(selected);
          isSelected ? next.remove(entry.$1) : next.add(entry.$1);
          onChanged(next);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle,
          child: Row(children: [
            TerminalCheckbox(value: isSelected, onChanged: (_) => toggle()),
            HSpace.x2,
            Expanded(child: TerminalText(entry.$2, role: TextRole.body)),
          ]),
        );
      }).toList(),
    );
  }
}
