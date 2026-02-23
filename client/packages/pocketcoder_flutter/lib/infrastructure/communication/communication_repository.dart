import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/chat/chat.dart';
import '../../domain/communication/i_communication_repository.dart';
import '../../domain/exceptions.dart';
import '../core/logger.dart';
import '../../core/try_operation.dart';
import 'communication_daos.dart';
import '../ai_config/ai_config_daos.dart';
import '../../domain/auth/i_auth_repository.dart';

@LazySingleton(as: ICommunicationRepository)
class CommunicationRepository implements ICommunicationRepository {
  final ChatDao _chatDao;
  final MessageDao _messageDao;
  final AiAgentDao _agentDao;
  final IAuthRepository _authRepository;

  CommunicationRepository(
    this._chatDao,
    this._messageDao,
    this._agentDao,
    this._authRepository,
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
        logInfo('CommunicationRepo: ensureChat(title: $title)');

        // Simple implementation: check if exists, else create
        final existing = await _chatDao.getFullList(
          filter: 'title = "$title"',
        );

        if (existing.isNotEmpty) {
          logInfo(
              'CommunicationRepo: Found existing chat: ${existing.first.id}');
          return existing.first.id;
        }

        logInfo(
            'CommunicationRepo: Chat not found, identifying "poco" agent...');

        // We assume 'poco' agent exists.
        // Use networkOnly to bypass pocketbase_drift's local IndexedDB caching,
        // which hangs on Chrome web after receiving the response for this collection.
        final agents = await _agentDao.getFullList(
          filter: 'name = "poco"',
          requestPolicy: RequestPolicy.networkOnly,
        );
        final agentId = agents.isNotEmpty ? agents.first.id : '';
        logInfo('CommunicationRepo: Using agentId: $agentId');

        final userId = _authRepository.currentUserId;
        logInfo('CommunicationRepo: Creating chat with userId: $userId');

        if (userId == null) {
          throw ChatException('Cannot create chat: User is not authenticated.');
        }

        final newChat = await _chatDao.save(null, {
          'title': title,
          'agent': agentId,
          'user': userId,
        });

        logInfo('CommunicationRepo: Created new chat: ${newChat.id}');
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
