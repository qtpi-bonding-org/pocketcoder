import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/chat/chat.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/chat/subagent.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class ChatDao extends BaseDao<Chat> {
  ChatDao(PocketBase pb) : super(pb, Collections.chats, Chat.fromJson);
}

@lazySingleton
class MessageDao extends BaseDao<ChatMessage> {
  MessageDao(PocketBase pb)
      : super(pb, Collections.messages, ChatMessage.fromJson);
}

@lazySingleton
class SubagentDao extends BaseDao<Subagent> {
  SubagentDao(PocketBase pb)
      : super(pb, Collections.subagents, Subagent.fromJson);
}
