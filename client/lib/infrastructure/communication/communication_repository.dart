import 'dart:async';
import 'package:injectable/injectable.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/chat/chat.dart';
import '../../domain/communication/i_communication_repository.dart';
import '../../domain/exceptions.dart';
import '../core/logger.dart';
import '../../core/try_operation.dart';
import 'communication_daos.dart';
import '../ai_config/ai_config_daos.dart';

@LazySingleton(as: ICommunicationRepository)
class CommunicationRepository implements ICommunicationRepository {
  final ChatDao _chatDao;
  final MessageDao _messageDao;
  final AiAgentDao _agentDao;

  CommunicationRepository(
    this._chatDao,
    this._messageDao,
    this._agentDao,
  );

  @override
  Stream<List<ChatMessage>> watchColdPipe(String chatId) {
    // We use the reactive watch from BaseDao
    return _messageDao.watch(
      filter: 'chat = "$chatId"',
      sort: 'created',
    );
  }

  @override
  Stream<HotPipeEvent> watchHotPipe() {
    // TODO: Connect this to the new parts-based streaming logic in Phase 2
    // For now, returning an empty stream to maintain compilation
    return const Stream.empty();
  }

  @override
  Future<void> sendMessage(String chatId, String content) async {
    return tryMethod(
      () async {
        logInfo('CommunicationRepo: Sending message to chat=$chatId');

        await _messageDao.save(null, {
          'chat': chatId,
          'role': 'user',
          'parts': [
            {'type': 'text', 'text': content}
          ],
        });

        logInfo('CommunicationRepo: Message created successfully');
      },
      ChatException.new,
      'sendMessage',
    );
  }

  @override
  Future<String> ensureChat(String title) async {
    return tryMethod(
      () async {
        // Simple implementation: check if exists, else create
        final existing = await _chatDao.getFullList(
          filter: 'title = "$title"',
        );

        if (existing.isNotEmpty) {
          return existing.first.id;
        }

        // We assume 'poco' agent exists
        final agents = await _agentDao.getFullList(
          filter: 'name = "poco"',
        );
        final agentId = agents.isNotEmpty ? agents.first.id : '';

        final newChat = await _chatDao.save(null, {
          'title': title,
          'agent': agentId,
          // user ID is handled by PocketBase create rules usually,
          // but we can add it if we have access to _pb.authStore
        });

        return newChat.id;
      },
      ChatException.new,
      'ensureChat',
    );
  }

  @override
  Future<String?> getOpencodeId(String chatId) async {
    return tryMethod(
      () async {
        final chat = await _chatDao.getOne(chatId);
        return chat.aiEngineSessionId;
      },
      ChatException.new,
      'getOpencodeId',
    );
  }

  @override
  Stream<Chat> watchChat(String chatId) {
    // We cast the stream of lists to a stream of single objects
    return _chatDao.watch(filter: 'id = "$chatId"').map((list) => list.first);
  }

  @override
  Future<List<Chat>> fetchChatHistory() async {
    return tryMethod(
      () async {
        return _chatDao.getFullList(sort: '-updated');
      },
      ChatException.new,
      'fetchChatHistory',
    );
  }
}
