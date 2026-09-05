import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

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

  bool get _agentWorking => chat.turn == ChatTurn.user;

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
    final timestamp = _formatRelativeTime(context, chat.lastActive);

    return Semantics(
      button: true,
      label: '$headline. $timestamp',
      child: InkWell(
        onTap: () => onOpen(chat.id),
        onLongPress: () => _showActions(context),
        child: Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _bullet(),
                  SizedBox(width: AppSizes.ch),
                  Expanded(
                    child: TerminalText(
                      headline,
                      role: TextRole.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (timestamp.isNotEmpty) ...[
                    SizedBox(width: AppSizes.ch),
                    TerminalText(timestamp, role: TextRole.label),
                  ],
                ],
              ),
              if (previewLine != null)
                Padding(
                  padding: EdgeInsets.only(left: AppSizes.ch * 2),
                  child: TerminalText(
                    previewLine,
                    role: TextRole.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet() =>
      _agentWorking ? const TerminalSpinner() : _StateBullet();

  void _showActions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: chat.title.toLowerCase(),
        content: TerminalText(
          context.l10n.chatListActionsBody(chat.title),
          role: TextRole.body,
        ),
        actions: [
          TerminalButton(
            label: context.l10n.chatListArchive,
            kind: ActionKind.neutral,
            onTap: () {
              Navigator.of(dialogContext).pop();
              onArchive(chat.id);
            },
          ),
          TerminalButton(
            label: context.l10n.chatListDelete,
            kind: ActionKind.destructive,
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

class _StateBullet extends StatelessWidget {
  const _StateBullet();

  @override
  Widget build(BuildContext context) =>
      TerminalText('●', role: SectionState.nominal.role);
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
