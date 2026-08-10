import 'package:flutter/material.dart';
import 'adapters/chat_list_adapter.dart';

/// Top-level screen for the chat-list landing pillar.
///
/// Provides the [ChatListCubit] via `BlocProvider(create: ...)`, cascading
/// both `watchChats()` (the live list) and `checkEmptyAndMaybeAutoCreate()`
/// (the one-shot, network-authoritative first-chat auto-create decision —
/// see `ChatListCubit`'s doc comment for why this is not driven by
/// `watchChats()`'s possibly cache-stale emissions). Mirrors
/// `AgentConfigScreen`/`ProviderScreen`'s screen/view split so widget tests
/// can pump [ChatListView] directly with a fake cubit.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatListScreenAdapter();
  }
}
