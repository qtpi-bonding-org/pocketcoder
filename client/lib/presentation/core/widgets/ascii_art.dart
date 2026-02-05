import 'package:flutter/material.dart';

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
┌───┐
│>_<│
└───┘''';

  static const String pocoAwake = r'''
┌───┐
│o_o│
└───┘''';

  static const String pocoHappy = r'''
┌───┐
│^_^│
└───┘''';

  static const String pocoSurprised = r'''
┌───┐
│O_O│
└───┘''';

  static const String pocoMistaken = r'''
┌───┐
│X_X│
└───┘''';
}

class AsciiFace extends StatelessWidget {
  final String face;
  final Color color;
  final double fontSize;

  const AsciiFace({
    super.key,
    required this.face,
    this.color = const Color(0xFF39FF14),
    this.fontSize = 16,
  });

  factory AsciiFace.pocoSleepy({Color? color, double? fontSize}) => AsciiFace(
      face: AppAscii.pocoSleepy,
      color: color ?? const Color(0xFF39FF14),
      fontSize: fontSize ?? 16);

  factory AsciiFace.pocoAwake({Color? color, double? fontSize}) => AsciiFace(
      face: AppAscii.pocoAwake,
      color: color ?? const Color(0xFF39FF14),
      fontSize: fontSize ?? 16);

  factory AsciiFace.pocoHappy({Color? color, double? fontSize}) => AsciiFace(
      face: AppAscii.pocoHappy,
      color: color ?? const Color(0xFF39FF14),
      fontSize: fontSize ?? 16);

  factory AsciiFace.pocoSurprised({Color? color, double? fontSize}) =>
      AsciiFace(
          face: AppAscii.pocoSurprised,
          color: color ?? const Color(0xFF39FF14),
          fontSize: fontSize ?? 16);

  factory AsciiFace.pocoMistaken({Color? color, double? fontSize}) => AsciiFace(
      face: AppAscii.pocoMistaken,
      color: color ?? const Color(0xFF39FF14),
      fontSize: fontSize ?? 16);

  @override
  Widget build(BuildContext context) {
    return Text(
      face,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        height: 1.0,
        fontFamily: 'Noto Sans Mono',
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: 0,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
