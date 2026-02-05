import 'package:flutter/material.dart';

/// A configuration object for a single footer button
class TerminalAction {
  final String keyLabel; // e.g. "F1"
  final String label; // e.g. "HELP"
  final VoidCallback onTap;

  TerminalAction({
    required this.keyLabel,
    required this.label,
    required this.onTap,
  });
}

class TerminalFooter extends StatelessWidget {
  final List<TerminalAction> actions;

  const TerminalFooter({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    // A single green line to separate footer from content
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black, // Background of the footer bar
        border: Border(
          top: BorderSide(color: Color(0xFF39FF14), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions.map((action) {
              return _buildFKeyButton(context, action);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFKeyButton(BuildContext context, TerminalAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        // The "Inverted" hover effect color (using Cyberpunk Green)
        splashColor: const Color(0xFF39FF14).withValues(alpha: 0.3),
        highlightColor: const Color(0xFF39FF14).withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: const BoxDecoration(
            // Adds a subtle divider line between buttons
            border: Border(
              right: BorderSide(color: Color(0xFF004400), width: 1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The "F-Key" part (Inverted block look)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                color: const Color(0xFF39FF14), // Solid Green Block
                child: Text(
                  action.keyLabel,
                  style: const TextStyle(
                    fontFamily: 'VT323',
                    color: Colors.black, // Black text on Green block
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // The Label part
              Text(
                action.label,
                style: const TextStyle(
                  fontFamily: 'VT323',
                  color: Color(0xFF39FF14), // Green text
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
