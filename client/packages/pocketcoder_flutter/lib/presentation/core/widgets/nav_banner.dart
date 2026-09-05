import 'package:flutter/widgets.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_logo.dart';

/// The wordmark a nav root wears instead of a title.
///
/// The art is 8 rows tall, so left to itself it fills the width and towers
/// over the content it introduces. Capping it at three text rows keeps it on
/// the character grid and reading as a heading rather than a splash screen.
class NavBanner extends StatelessWidget {
  const NavBanner({super.key, required this.pillar});

  final NavPillar pillar;

  static double get height => AppSizes.line * 3;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: AsciiLogo(text: AppAscii.bannerFor(pillar)),
      );
}
