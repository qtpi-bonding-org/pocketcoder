import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/domain/models/subagent.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/core/collections.dart';

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
class SubagentDao extends BaseDao<Subagent> {
  SubagentDao(PocketBase pb)
      : super(pb, Collections.subagents, Subagent.fromJson);
}
