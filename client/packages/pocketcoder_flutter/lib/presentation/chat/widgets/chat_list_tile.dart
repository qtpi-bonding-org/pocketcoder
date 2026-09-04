import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    required this.onOpen,
    required this.onArchive,
    required this.onDelete,
  });

  final Chat chat;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onArchive;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final firstMessage = chat.firstMessage;
    final preview = chat.preview;
    final headline = (firstMessage != null && firstMessage.isNotEmpty)
        ? firstMessage
        : ((preview != null && preview.isNotEmpty)
            ? preview
            : context.l10n.chatListNoMessages);
    final previewLine = (preview != null &&
            preview.isNotEmpty &&
            preview != firstMessage &&
            firstMessage != null &&
            firstMessage.isNotEmpty)
        ? preview
        : null;

    return Semantics(
      button: true,
      label: '$headline. ${_formatRelativeTime(context, chat.lastActive)}',
      child: InkWell(
        onTap: () => onOpen(chat.id),
        onLongPress: () => _showActions(context),
        child: Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TerminalText(
                headline,
                role: TextRole.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (previewLine != null)
                TerminalText(
                  previewLine,
                  role: TextRole.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (chat.lastActive != null)
                TerminalText(
                  _formatRelativeTime(context, chat.lastActive),
                  role: TextRole.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: chat.title.toLowerCase(),
        content: const SizedBox.shrink(),
        actions: [
          TerminalButton(
            label: context.l10n.chatListArchive,
            isPrimary: false,
            onTap: () {
              Navigator.of(dialogContext).pop();
              onArchive(chat.id);
            },
          ),
          HSpace.x2,
          TerminalButton(
            label: context.l10n.chatListDelete,
            isPrimary: false,
            onTap: () {
              Navigator.of(dialogContext).pop();
              onDelete(chat.id);
            },
          ),
        ],
      ),
    );
  }
}

String _formatRelativeTime(BuildContext context, DateTime? time) {
  if (time == null) return '';

  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) {
    return context.l10n.chatListTimestampNow;
  }
  if (diff.inHours < 1) {
    return context.l10n.chatListTimestampMinutesAgo(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return context.l10n.chatListTimestampHoursAgo(diff.inHours);
  }
  if (diff.inDays < 7) {
    return context.l10n.chatListTimestampDaysAgo(diff.inDays);
  }
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}
