import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/communication/i_chat_repository.dart';
import 'package:flutter_aeroform/domain/exceptions.dart';
import "package:flutter_aeroform/infrastructure/core/logger.dart";
import 'package:flutter_aeroform/core/try_operation.dart';
import 'communication_daos.dart';
import '../ai_config/ai_config_daos.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_client.dart';

@LazySingleton(as: IChatRepository)
class ChatRepository implements IChatRepository {
  final ChatDao _chatDao;
  final MessageDao _messageDao;
  final AiAgentDao _agentDao;
  final IAuthRepository _authRepository;
  final PocketCoderApi _api;

  ChatRepository(
    this._chatDao,
    this._messageDao,
    this._agentDao,
    this._authRepository,
    this._api,
  );

  @override
  Stream<List<Message>> watchColdPipe(String chatId) {
    // We use the reactive watch from BaseDao
    return _messageDao.watch(
      filter: 'chat = "$chatId"',
      sort: 'created',
    );
  }

  @override
  Stream<HotPipeEvent> watchHotPipe(String chatId) {
    final controller = StreamController<HotPipeEvent>();
    final topic = 'chats:$chatId';

    logInfo('💬 [HotPipe] Subscribing via Broker to $topic');

    try {
      _chatDao.pb.realtime.subscribe(topic, (e) {
        if (e.event != topic || e.data.isEmpty) return;

        try {
          final dataMap = jsonDecode(e.data) as Map<String, dynamic>;
          // PB Dart puts the custom message payload in the `e.record` object as a raw map sometimes,
          // but we actually structured the payload as {"event": "...", "data": {...}} in go.
          final eventType = dataMap['event'] as String?;
          final payload = dataMap['data'] as Map<String, dynamic>? ?? {};

          final messageId = payload['messageID'] as String? ?? 'unknown';

          switch (eventType) {
            case 'text_delta':
              controller.add(HotPipeEvent.textDelta(
                messageId: messageId,
                partId: payload['partID'] as String? ?? '',
                text: payload['text'] as String? ?? '',
              ));
            case 'tool_status':
              controller.add(HotPipeEvent.toolStatus(
                messageId: messageId,
                partId: payload['partID'] as String? ?? '',
                tool: payload['tool'] as String? ?? '',
                status: payload['status'] as String? ?? '',
              ));
            case 'message_snapshot':
              final parts = (payload['parts'] as List? ?? [])
                  .cast<Map<String, dynamic>>()
                  .toList();
              controller.add(HotPipeEvent.snapshot(
                messageId: messageId,
                parts: parts,
                role: payload['role'] as String?,
              ));
            case 'message_complete':
              final parts = (payload['parts'] as List? ?? [])
                  .cast<Map<String, dynamic>>()
                  .toList();
              controller.add(HotPipeEvent.complete(
                messageId: messageId,
                parts: parts,
                status: payload['status'] as String?,
                role: payload['role'] as String?,
              ));
            case 'message_error':
              controller.add(HotPipeEvent.error(
                messageId: messageId,
                error: payload['error'] as Map<String, dynamic>? ?? {},
              ));
          }
        } catch (e, stack) {
          logError('💬 [HotPipe] Failed to parse Broker event', e, stack);
        }
      }).catchError((e, stack) {
        logError('💬 [HotPipe] Broker subscription failed', e, stack);
        controller.addError(e, stack);
        return () async {};
      });
    } catch (e, stack) {
      logError('💬 [HotPipe] Failed to initiate Broker subscription', e, stack);
      controller.addError(e, stack);
    }

    controller.onCancel = () async {
      logInfo('💬 [HotPipe] Unsubscribing from Broker');
      await _chatDao.pb.realtime.unsubscribe(topic);
    };

    return controller.stream;
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
        // On web (Chrome), use networkOnly to bypass pocketbase_drift's local
        // IndexedDB caching, which hangs when writing this collection.
        // On native (iOS, macOS, Android), the default cacheAndNetwork is safe.
        final agents = await _agentDao.getFullList(
          filter: 'name = "poco"',
          requestPolicy: kIsWeb ? RequestPolicy.networkOnly : null,
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

  @override
  String getArtifactUrl(String path) {
    return _api.getArtifactUrl(path);
  }

  @override
  Future<String> fetchArtifact(String path) async {
    return tryMethod(
      () => _api.fetchArtifact(path),
      ChatException.new,
      'fetchArtifact',
    );
  }
}
