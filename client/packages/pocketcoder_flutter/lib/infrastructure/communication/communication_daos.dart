import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/domain/models/sandbox_agent.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";

@lazySingleton
class ChatDao extends BaseDao<Chat> {
  ChatDao(PocketBase pb) : super(pb, Collections.chats, Chat.fromJson);
}

@lazySingleton
class MessageDao extends BaseDao<Message> {
  MessageDao(PocketBase pb)
      : super(pb, Collections.messages, Message.fromJson);
}

@lazySingleton
class SandboxAgentDao extends BaseDao<SandboxAgent> {
  SandboxAgentDao(PocketBase pb)
      : super(pb, Collections.sandboxAgents, SandboxAgent.fromJson);
}
