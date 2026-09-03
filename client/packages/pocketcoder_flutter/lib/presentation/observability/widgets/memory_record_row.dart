import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

class MemoryRecordRow extends StatelessWidget {
  const MemoryRecordRow({
    super.key,
    required this.author,
    required this.createdAt,
    required this.body,
    this.linkedObservations,
  });

  final String author;
  final String createdAt;
  final String body;
  final List<String>? linkedObservations;

  @override
  Widget build(BuildContext context) {
    final linked = linkedObservations ?? const <String>[];
    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.space),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$author · $createdAt',
            style: TextStyle(
              color: context.colorScheme.primary,
              fontFamily: AppFonts.bodyFamily,
              fontSize: AppSizes.fontMini,
            ),
          ),
          Text(
            body,
            style: TextStyle(
              color: context.colorScheme.onSurface,
              fontFamily: AppFonts.bodyFamily,
            ),
          ),
          if (linked.isNotEmpty)
            Text(
              'Linked: ${linked.join(' | ')}',
              style: TextStyle(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
        ],
      ),
    );
  }
}
