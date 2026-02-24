import 'package:flutter/material.dart';
import '../../../design_system/theme/app_theme.dart';

class PocoExpression {
  static const String sleepy = '-_-';
  static const String nervous = '~_~';
  static const String thinking = '>_<';
  static const String awake = 'o_o';
  static const String happy = '^_^';
  static const String surprised = 'O_O';
  static const String mistaken = 'X_X';
  static const String panic = '@_@';
  static const String sad = 'T_T';
  static const String cheeky = '^_~';
  static const String lookRight = '>_>';
  static const String lookLeft = '<_<';
  static const String greedy = '\$_\$';
  static const String mad = 'ò_ó';
  static const String skeptical = '¬_¬';
  static const String amazed = '*_*';
  static const String shy = 'u_u';
  static const String winkLeft = '^_-';
  static const String winkRight = '-_^';
  static const String vigilantLeft = 'o_-';
  static const String vigilantRight = '-_o';
}

enum PocoArmor {
  standard,
  fortified,
}

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

  static String build(String expression,
      [PocoArmor armor = PocoArmor.standard]) {
    switch (armor) {
      case PocoArmor.fortified:
        return '''
╔═════╗
║ $expression ║
╚═════╝''';

      case PocoArmor.standard:
        return '''
┌─────┐
│ $expression │
└─────┘''';
    }
  }
}

class AsciiFace extends StatelessWidget {
  final String expression;
  final PocoArmor armor;
  final Color? color;
  final double? fontSize;

  const AsciiFace({
    super.key,
    required this.expression,
    this.armor = PocoArmor.standard,
    this.color,
    this.fontSize,
  });

  // --- Factory Constructors ---
  // You can now pass 'armor' to any of these if you want to override the default.

  factory AsciiFace.sleepy(
          {PocoArmor armor = PocoArmor.standard,
          Color? color,
          double? fontSize}) =>
      AsciiFace(
          expression: PocoExpression.sleepy,
          armor: armor,
          color: color,
          fontSize: fontSize);

  factory AsciiFace.awake(
          {PocoArmor armor = PocoArmor.standard,
          Color? color,
          double? fontSize}) =>
      AsciiFace(
          expression: PocoExpression.awake,
          armor: armor,
          color: color,
          fontSize: fontSize);

  factory AsciiFace.happy(
          {PocoArmor armor = PocoArmor.standard,
          Color? color,
          double? fontSize}) =>
      AsciiFace(
          expression: PocoExpression.happy,
          armor: armor,
          color: color,
          fontSize: fontSize);

  factory AsciiFace.surprised(
          {PocoArmor armor = PocoArmor.standard,
          Color? color,
          double? fontSize}) =>
      AsciiFace(
          expression: PocoExpression.surprised,
          armor: armor,
          color: color,
          fontSize: fontSize);

  factory AsciiFace.mistaken(
          {PocoArmor armor = PocoArmor.standard,
          Color? color,
          double? fontSize}) =>
      AsciiFace(
          expression: PocoExpression.mistaken,
          armor: armor,
          color: color,
          fontSize: fontSize);

  factory AsciiFace.thinking(
          {PocoArmor armor = PocoArmor.standard,
          Color? color,
          double? fontSize}) =>
      AsciiFace(
          expression: PocoExpression.thinking,
          armor: armor,
          color: color,
          fontSize: fontSize);

  @override
  Widget build(BuildContext context) {
    // Prefer passed color/size, fallback to design system
    final effectiveColor = color ?? context.colorScheme.onSurface;
    final effectiveSize = fontSize ?? AppSizes.fontStandard;

    // Dynamically build the string based on Armor + Expression
    final fullFaceString = AppAscii.build(expression, armor);

    return Text(
      fullFaceString,
      style: TextStyle(
        color: effectiveColor,
        fontSize: effectiveSize,
        height: 1.0,
        fontFamily: AppFonts.bodyFamily,
        package: 'pocketcoder_flutter',
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: 0,
        fontWeight: AppFonts.heavy,
      ),
    );
  }
}
