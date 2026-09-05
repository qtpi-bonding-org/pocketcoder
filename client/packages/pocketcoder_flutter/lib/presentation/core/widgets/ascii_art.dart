import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

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

class AppAscii {
  static const String navChat = r'''
                            
   ▄▄▄  █               ▄   
 ▄▀   ▀ █ ▄▄    ▄▄▄   ▄▄█▄▄ 
 █      █▀  █  ▀   █    █   
 █      █   █  ▄▀▀▀█    █   
  ▀▄▄▄▀ █   █  ▀▄▄▀█    ▀▄▄ 
                            
                  ''';

  static const String navConfig = r'''
                                          
   ▄▄▄                  ▄▀▀    ▀          
 ▄▀   ▀  ▄▄▄   ▄ ▄▄   ▄▄█▄▄  ▄▄▄     ▄▄▄▄ 
 █      █▀ ▀█  █▀  █    █      █    █▀ ▀█ 
 █      █   █  █   █    █      █    █   █ 
  ▀▄▄▄▀ ▀█▄█▀  █   █    █    ▄▄█▄▄  ▀█▄▀█ 
                                     ▄  █ 
                                      ▀▀  
''';

  static const String navStatus = r'''
                                          
  ▄▄▄▄    ▄             ▄                 
 █▀   ▀ ▄▄█▄▄   ▄▄▄   ▄▄█▄▄  ▄   ▄   ▄▄▄  
 ▀█▄▄▄    █    ▀   █    █    █   █  █   ▀ 
     ▀█   █    ▄▀▀▀█    █    █   █   ▀▀▀▄ 
 ▀▄▄▄█▀   ▀▄▄  ▀▄▄▀█    ▀▄▄  ▀▄▄▀█  ▀▄▄▄▀ 
                                          
                         ''';

  static const String navControl = r'''
                                                 
   ▄▄▄                  ▄                  ▀▀█   
 ▄▀   ▀  ▄▄▄   ▄ ▄▄   ▄▄█▄▄   ▄ ▄▄   ▄▄▄     █   
 █      █▀ ▀█  █▀  █    █     █▀  ▀ █▀ ▀█    █   
 █      █   █  █   █    █     █     █   █    █   
  ▀▄▄▄▀ ▀█▄█▀  █   █    ▀▄▄   █     ▀█▄█▀    ▀▄▄ 
                                                 
                          ''';

  static String bannerFor(NavPillar pillar) => switch (pillar) {
        NavPillar.chat => navChat,
        NavPillar.config => navConfig,
        NavPillar.status => navStatus,
        NavPillar.control => navControl,
      };

  static const String pocketCoderProLogo = r'''
 ______   ______    ______
/\  == \ /\  == \  /\  __ \
\ \  _-/ \ \  __<  \ \ \/\ \
 \ \_\    \ \_\ \_\ \ \_____\
  \/_/     \/_/ /_/  \/_____/ ''';

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

  /// Retained as a convenient source for clients that need the legacy shape.
  static String build(String expression,
      [PocoPosture posture = PocoPosture.armored]) {
    switch (posture) {
      case PocoPosture.armored:
        return '\n┌─────┐\n│ $expression │\n└─────┘';
      case PocoPosture.fortified:
        return '\n╔═════╗\n║ $expression ║\n╚═════╝';
    }
  }
}

class AsciiFace extends StatelessWidget {
  final String expression;
  final PocoPosture posture;
  final PocoMood? mood;
  final Color? color;
  final double? fontSize;

  const AsciiFace({
    super.key,
    required this.expression,
    this.posture = PocoPosture.armored,
    this.mood,
    this.color,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? mood?.color ?? _moodFor(expression).color;
    final effectiveSize = fontSize ?? AppSizes.fontBody;
    final style = TextStyle(
      color: effectiveColor,
      fontSize: effectiveSize,
      height: 1.0,
      fontFamily: AppFonts.family,
      package: 'pocketcoder_flutter',
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: 0,
      fontWeight: AppFonts.heavy,
    );
    final frame = posture == PocoPosture.armored
        ? '┌─────┐\n│     │\n└─────┘'
        : '╔═════╗\n║     ║\n╚═════╝';
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(frame, key: const ValueKey('poco-frame'), style: style),
        Text(expression, key: const ValueKey('poco-face'), style: style),
      ],
    );
  }

  PocoMood _moodFor(String value) => switch (value) {
        PocoExpression.happy => PocoMood.happy,
        PocoExpression.awake => PocoMood.awake,
        PocoExpression.cheeky => PocoMood.cheeky,
        PocoExpression.amazed => PocoMood.amazed,
        PocoExpression.thinking => PocoMood.thinking,
        PocoExpression.winkLeft => PocoMood.winkLeft,
        PocoExpression.winkRight => PocoMood.winkRight,
        PocoExpression.sleepy => PocoMood.sleepy,
        PocoExpression.shy => PocoMood.shy,
        PocoExpression.nervous => PocoMood.nervous,
        PocoExpression.vigilantLeft => PocoMood.vigilantLeft,
        PocoExpression.vigilantRight => PocoMood.vigilantRight,
        PocoExpression.skeptical => PocoMood.skeptical,
        PocoExpression.surprised => PocoMood.surprised,
        PocoExpression.lookRight => PocoMood.lookRight,
        PocoExpression.lookLeft => PocoMood.lookLeft,
        PocoExpression.mad => PocoMood.mad,
        PocoExpression.mistaken => PocoMood.mistaken,
        PocoExpression.panic => PocoMood.panic,
        PocoExpression.sad => PocoMood.sad,
        _ => PocoMood.awake,
      };
}
