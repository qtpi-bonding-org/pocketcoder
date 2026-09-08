import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/dot_spinner.dart';

class TerminalSpinner extends StatelessWidget {
  const TerminalSpinner({super.key});

  @override
  Widget build(BuildContext context) => const DotSpinner(role: TextRole.body);
}
