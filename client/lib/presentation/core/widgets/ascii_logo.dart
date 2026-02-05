import 'package:flutter/material.dart';

class AsciiLogo extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const AsciiLogo({
    super.key,
    required this.text,
    this.color = const Color(0xFF39FF14),
    this.fontSize = 8,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          height: 1.1,
          fontWeight: FontWeight.bold,
          fontFamily: 'VT323',
          shadows: [
            Shadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
