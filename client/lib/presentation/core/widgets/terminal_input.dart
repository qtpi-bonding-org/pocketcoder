import 'package:flutter/material.dart';

class TerminalInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String prompt;

  const TerminalInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.prompt = '%',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Row(
        children: [
          Text(
            '$prompt ',
            style: const TextStyle(
              color: Color(0xFF39FF14),
              fontFamily: 'Noto Sans Mono',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmitted(),
              style: const TextStyle(
                color: Color(0xFF39FF14),
                fontFamily: 'Noto Sans Mono',
                fontSize: 16,
              ),
              cursorColor: const Color(0xFF39FF14),
              cursorWidth: 10.0, // Block style
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
