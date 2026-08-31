import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';

/// A header made of one or more rows (typically BiosRow), an optional
/// custom body slot, and an optional BiosActionStrip footer -- the
/// composition that lets richer settings/status screens fold in without
/// forcing their unique parts into a single BiosRow shape that doesn't fit
/// them.
///
/// Reuses TerminalCard for its border/isActive chrome rather than
/// reimplementing it -- BiosCard is purely a header+body+footer layout on
/// top of the card look every management screen already has.
///
/// BiosCard holds no expansion state of its own: the inline-accordion case
/// (a header BiosRow in `expand` variant revealing detail in place) is the
/// caller's own `bool _isExpanded`, toggled by the header row's `onTap` and
/// passed straight through as `body: _isExpanded ? <content> : null`.
class BiosCard extends StatelessWidget {
  const BiosCard({
    super.key,
    required this.header,
    this.body,
    this.footer,
    this.isActive = false,
  });

  final List<Widget> header;
  final Widget? body;
  final BiosActionStrip? footer;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      isActive: isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...header,
          if (body case final body?) ...[VSpace.x1, body],
          if (footer case final footer?) ...[VSpace.x1, footer],
        ],
      ),
    );
  }
}
