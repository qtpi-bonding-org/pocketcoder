import 'package:flutter/material.dart';
import '../../../design_system/primitives/app_fonts.dart';
import '../../../design_system/primitives/app_palette.dart';
import '../../../design_system/primitives/app_sizes.dart';

class AppAscii {
  static const String pocketCoderLogo = r'''
 ______   ______     ______     __  __     ______     ______  
/\  == \ /\  __ \   /\  ___\   /\ \/ /    /\  ___\   /\__  _\ 
\ \  _-/ \ \ \/\ \  \ \ \____  \ \  _"-.  \ \  __\   \/_/\ \/ 
 \ \_\    \ \_____\  \ \_____\  \ \_\ \_\  \ \_____\    \ \_\ 
  \/_/     \/_____/   \/_____/   \/_/\/_/   \/_____/     \/_/ 
                                                              
       ______     ______     _____     ______     ______      
      /\  ___\   /\  __ \   /\  __-.  /\  ___\   /\  == \     
      \ \ \____  \ \ \/\ \  \ \ \/\ \ \ \  __\   \ \  __<     
       \ \_____\  \ \_____\  \ \____-  \ \_____\  \ \_\ \_\   
        \/_____/   \/_____/   \/____/   \/_____/   \/_/ /_/   ''';

  static const String pocoSleepy = r'''
┌─────┐
│ -_- │
└─────┘''';

  static const String pocoThinking = r'''
┌─────┐
│ >_< │
└─────┘''';

  static const String pocoAwake = r'''
┌─────┐
│ o_o │
└─────┘''';

  static const String pocoHappy = r'''
┌─────┐
│ ^_^ │
└─────┘''';

  static const String pocoSurprised = r'''
┌─────┐
│ O_O │
└─────┘''';

  static const String pocoMistaken = r'''
┌─────┐
│ X_X │
└─────┘''';

  // 3. The "Panic" (Use for critical system failures or 500 errors)
  static const String pocoPanic = r'''
┌─────┐
│ @_@ │
└─────┘''';

  // 4. The "Sad" (Use when a task is cancelled or fails)
  static const String pocoSad = r'''
┌─────┐
│ T_T │
└─────┘''';

  // 5. The "Sassy" (Use for random flavor or Easter eggs)
  static const String pocoCheeky = r'''
┌─────┐
│ ^_~ │
└─────┘''';

  // 6. The "Suspicious" (Use when confidence is low or verifying keys)
  static const String pocoSuspicious = r'''
┌─────┐
│ >_> │
└─────┘''';

  // 7. The "Greedy" (Use if you ever add a paid feature or commercial license check)
  static const String pocoGreedy = r'''
┌─────┐
│ $_$ │
└─────┘''';

  // 8. The "Focus" (Use during really hard computations)
  static const String pocoMad = r'''
┌─────┐
│ ò_ó │
└─────┘''';
}

class AsciiFace extends StatelessWidget {
  final String face;
  final Color? color;
  final double? fontSize;

  const AsciiFace({
    super.key,
    required this.face,
    this.color,
    this.fontSize,
  });

  factory AsciiFace.pocoSleepy({Color? color, double? fontSize}) =>
      AsciiFace(face: AppAscii.pocoSleepy, color: color, fontSize: fontSize);

  factory AsciiFace.pocoAwake({Color? color, double? fontSize}) =>
      AsciiFace(face: AppAscii.pocoAwake, color: color, fontSize: fontSize);

  factory AsciiFace.pocoHappy({Color? color, double? fontSize}) =>
      AsciiFace(face: AppAscii.pocoHappy, color: color, fontSize: fontSize);

  factory AsciiFace.pocoSurprised({Color? color, double? fontSize}) =>
      AsciiFace(face: AppAscii.pocoSurprised, color: color, fontSize: fontSize);

  factory AsciiFace.pocoMistaken({Color? color, double? fontSize}) =>
      AsciiFace(face: AppAscii.pocoMistaken, color: color, fontSize: fontSize);

  @override
  Widget build(BuildContext context) {
    // Prefer passed color/size, fallback to design system
    final effectiveColor = color ?? AppPalette.primary.textPrimary;
    final effectiveSize = fontSize ?? AppSizes.fontStandard;

    return Text(
      face,
      style: TextStyle(
        color: effectiveColor,
        fontSize: effectiveSize,
        height: 1.0,
        fontFamily: AppFonts.bodyFamily,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: 0,
        fontWeight: AppFonts.heavy,
      ),
    );
  }
}
