import 'dart:async';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/models/message.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/domain/communication/i_communication_repository.dart';
import 'package:flutter_aeroform/domain/exceptions.dart';
import "package:flutter_aeroform/infrastructure/core/logger.dart";
import 'package:flutter_aeroform/core/try_operation.dart';
import 'communication_daos.dart';
import '../ai_config/ai_config_daos.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_client.dart';

@LazySingleton(as: ICommunicationRepository)
class CommunicationRepository implements ICommunicationRepository {
  final ChatDao _chatDao;
  final MessageDao _messageDao;
  final AiAgentDao _agentDao;
  final IAuthRepository _authRepository;
  final PocketCoderApi _api;

  CommunicationRepository(
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
    final url = "${_chatDao.pb.baseURL}/api/chats/$chatId/stream";

    logInfo('💬 [HotPipe] Subscribing to $url');

    final subscription = SSEClient.subscribeToSSE(
      method: SSERequestType.GET,
      url: url,
      header: {
        "Accept": "text/event-stream",
        "Cache-Control": "no-cache",
      },
    ).listen((event) {
      if (event.event == null || event.data == null || event.data!.isEmpty)
        return;

      try {
        final data = jsonDecode(event.data!) as Map<String, dynamic>;
        final messageId = data['messageID'] as String? ?? 'unknown';

        switch (event.event) {
          case 'text_delta':
            controller.add(HotPipeEvent.textDelta(
              messageId: messageId,
              partId: data['partID'] as String? ?? '',
              text: data['text'] as String? ?? '',
            ));
          case 'tool_status':
            controller.add(HotPipeEvent.toolStatus(
              messageId: messageId,
              partId: data['partID'] as String? ?? '',
              tool: data['tool'] as String? ?? '',
              status: data['status'] as String? ?? '',
            ));
          case 'message_snapshot':
            final parts = (data['parts'] as List? ?? [])
                .cast<Map<String, dynamic>>()
                .toList();
            controller.add(HotPipeEvent.snapshot(
              messageId: messageId,
              parts: parts,
              role: data['role'] as String?,
            ));
          case 'message_complete':
            final parts = (data['parts'] as List? ?? [])
                .cast<Map<String, dynamic>>()
                .toList();
            controller.add(HotPipeEvent.complete(
              messageId: messageId,
              parts: parts,
              status: data['status'] as String?,
              role: data['role'] as String?,
            ));
          case 'error':
            controller.add(HotPipeEvent.error(
              messageId: messageId,
              error: data['envelope'] as Map<String, dynamic>? ?? {},
            ));
        }
      } catch (e, stack) {
        logError('💬 [HotPipe] Failed to parse SSE event', e, stack);
      }
    }, onError: (e, stack) {
      logError('💬 [HotPipe] SSE Stream error', e, stack);
      controller.addError(e, stack);
    }, onDone: () {
      logInfo('💬 [HotPipe] SSE Stream closed');
      controller.close();
    });

    controller.onCancel = () {
      logInfo('💬 [HotPipe] Unsubscribing from SSE');
      subscription.cancel();
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
