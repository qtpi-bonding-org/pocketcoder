import 'package:flutter/material.dart';
import '../../../../design_system/primitives/app_fonts.dart';
import '../../../../design_system/primitives/app_palette.dart';
import '../../../../design_system/primitives/app_sizes.dart';
import '../../../../domain/chat/chat_message.dart';

class ThoughtsStream extends StatelessWidget {
  final List<MessagePart> parts;

  const ThoughtsStream({super.key, required this.parts});

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return Center(
        child: Text(
          '[NEURAL LINK ACTIVE. WAITING FOR THOUGHTS...]',
          style: TextStyle(
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.3),
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontTiny,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSizes.space),
      itemCount: parts.length,
      reverse: true, // Auto-scroll to bottom of thoughts
      itemBuilder: (context, index) {
        // Reverse index for 'reverse: true'
        final part = parts[parts.length - 1 - index];
        return _buildPart(context, part);
      },
    );
  }

  Widget _buildPart(BuildContext context, MessagePart part) {
    return part.map(
      text: (textPart) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            '> ${textPart.text ?? ""}',
            style: TextStyle(
              color: AppPalette.primary.textPrimary.withValues(alpha: 0.6),
              fontFamily: AppFonts.headerFamily,
              fontSize: 10,
            ),
          ),
        );
      },
      reasoning: (reasoningPart) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            'THOUGHT: ${reasoningPart.text ?? ""}',
            style: TextStyle(
              color: AppPalette.primary.textPrimary.withValues(alpha: 0.4),
              fontFamily: AppFonts.bodyFamily,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      },
      tool: (toolPart) {
        final state = toolPart.state;
        return Container(
          margin: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border:
                Border(left: BorderSide(color: _getToolColor(state), width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'EXEC: ${toolPart.tool.toUpperCase()}',
                    style: TextStyle(
                      color: _getToolColor(state),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildToolStatus(state),
                ],
              ),
              _buildToolPayload(state),
            ],
          ),
        );
      },
      file: (filePart) => Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Text(
          'FILE [${filePart.mime}]: ${filePart.filename ?? filePart.url}',
          style: const TextStyle(color: Colors.blue, fontSize: 9),
        ),
      ),
      stepStart: (startPart) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Divider(
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.1),
            height: 1),
      ),
      stepFinish: (finishPart) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          'STEP COMPLETE (${finishPart.reason})',
          style: TextStyle(
            color: AppPalette.primary.textPrimary.withValues(alpha: 0.4),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Color _getToolColor(ToolState state) {
    return state.map(
      pending: (_) => Colors.grey,
      running: (_) => AppPalette.primary.primaryColor,
      completed: (_) => Colors.green,
      error: (_) => Colors.red,
    );
  }

  Widget _buildToolStatus(ToolState state) {
    String label = state.map(
      pending: (_) => '[PENDING]',
      running: (_) => '[RUNNING...]',
      completed: (_) => '[FINISHED]',
      error: (_) => '[FAILED]',
    );
    return Text(
      label,
      style: TextStyle(
        color: _getToolColor(state).withValues(alpha: 0.6),
        fontSize: 8,
      ),
    );
  }

  Widget _buildToolPayload(ToolState state) {
    return state.map(
      pending: (s) => _jsonText(s.input),
      running: (s) => _jsonText(s.input),
      completed: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _jsonText(s.input),
          const Divider(height: 8, color: Colors.white12),
          Text(
            s.output,
            style: const TextStyle(color: Colors.green, fontSize: 9),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      error: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _jsonText(s.input),
          const Divider(height: 8, color: Colors.white12),
          Text(
            s.error,
            style: const TextStyle(color: Colors.red, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _jsonText(Map<String, dynamic> json) {
    return Text(
      json.toString(),
      style: TextStyle(
        color: AppPalette.primary.textPrimary.withValues(alpha: 0.8),
        fontSize: 9,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
