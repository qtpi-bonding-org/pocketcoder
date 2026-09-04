import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

/// The aggregate state of everything inside a section. A section with no
/// state concept is [nominal] -- green, per spec section 2.
enum SectionState {
  nominal(TextRole.ok),
  attention(TextRole.warn),
  failed(TextRole.fail);

  const SectionState(this.role);
  final TextRole role;
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.name,
    this.state = SectionState.nominal,
  });

  final String name;
  final SectionState state;

  @override
  Widget build(BuildContext context) => Padding(
        // One blank line of separation from the previous section --
        // space does what the divider used to do.
        padding: EdgeInsets.only(top: AppSizes.line),
        child: Row(
          children: [
            TerminalText('●', role: state.role),
            HSpace.x1,
            TerminalText(name, role: TextRole.value),
          ],
        ),
      );
}
