import 'dart:async';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/chat/i_chat_repository.dart';
import '../../domain/chat/chat.dart';
import '../../domain/exceptions.dart';
import '../core/collections.dart';
import '../core/logger.dart';
import '../../core/try_operation.dart';

@LazySingleton(as: IChatRepository)
class ChatRepository implements IChatRepository {
  final PocketBase _pb;

  ChatRepository(this._pb);

  @override
  Stream<List<ChatMessage>> watchColdPipe(String chatId) async* {
    // Helper to fetch current state
    Future<List<ChatMessage>> fetch() async {
      return tryMethod(
        () async {
          final records = await _pb.collection(Collections.messages).getList(
                filter: 'chat = "$chatId"',
                sort: 'created',
                expand: 'chat',
              );

          return records.items
              .map((r) => ChatMessage.fromJson({
                    ...r.data,
                    'id': r.id,
                    'chatId': chatId,
                    'created': r.get<String>('created'),
                    'updated': r.get<String>('updated'),
                  }))
              .toList();
        },
        ChatException.new,
        'watchColdPipe.fetch',
      );
    }

    // Emit initial
    yield await fetch();

    // Subscribe to changes
    final controller = StreamController<List<ChatMessage>>();

    final unsubscribe = await _pb.collection(Collections.messages).subscribe('*', (e) async {
      try {
        final currentMessages = await fetch();
        if (!controller.isClosed) {
          controller.add(currentMessages);
        }
      } catch (e, stack) {
        logError('Error re-fetching messages on update', e, stack);
      }
    });

    try {
      yield* controller.stream;
    } finally {
      unsubscribe();
      controller.close();
    }
  }

  @override
  Stream<HotPipeEvent> watchHotPipe() async* {
    final controller = StreamController<HotPipeEvent>();

    final unsubscribe = await _pb.realtime.subscribe('logs', (e) {
      final dynamic payload = e.data;
      if (payload is Map) {
        if (payload['type'] == 'delta') {
          controller.add(HotPipeEvent.delta(
            content: (payload['content'] as String?) ?? '',
            callId: payload['callID'] as String?,
            tool: payload['tool'] as String?,
          ));
        } else if (payload['type'] == 'system') {
          controller.add(HotPipeEvent.system(text: (payload['text'] as String?) ?? ''));
        } else if (payload['type'] == 'finish') {
          controller.add(const HotPipeEvent.finish());
        }
      }
    });

    try {
      yield* controller.stream;
    } finally {
      unsubscribe();
      controller.close();
    }
  }

  @override
  Future<void> sendMessage(String chatId, String content) async {
    return tryMethod(
      () async {
        logInfo('Creating message in PB chat=$chatId');

        await _pb.collection(Collections.messages).create(body: {
          'chat': chatId,
          'role': 'user',
          'parts': [
            {'type': 'text', 'text': content}
          ],
        });

        logInfo('Message created successfully');
      },
      ChatException.new,
      'sendMessage',
    );
  }

  @override
  Future<String> ensureChat(String title) async {
    return tryMethod(
      () async {
        final userId = _pb.authStore.record?.id;
        if (userId == null) {
          throw AuthException.notAuthenticated();
        }

        final records = await _pb.collection(Collections.chats).getList(
              filter: 'title = "$title" && user = "$userId"',
              perPage: 1,
            );

        if (records.items.isNotEmpty) {
          return records.items.first.id;
        }

        final agentRecord = await _pb.collection(Collections.aiAgents).getFirstListItem(
              'name = "poco"',
            );

        final newChat = await _pb.collection(Collections.chats).create(body: {
          'title': title,
          'user': userId,
          'agent': agentRecord.id,
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
        final chat = await _pb.collection(Collections.chats).getOne(chatId);
        return chat.getStringValue('opencode_id');
      },
      ChatException.new,
      'getOpencodeId',
    );
  }

  @override
  Stream<RecordModel> watchChat(String chatId) async* {
    final controller = StreamController<RecordModel>();

    final unsubscribe = await _pb.collection(Collections.chats).subscribe(chatId, (e) {
      if (e.record != null) {
        controller.add(e.record!);
      }
    });

    try {
      yield* controller.stream;
    } finally {
      unsubscribe();
      controller.close();
    }
  }

  @override
  Future<List<Chat>> fetchChatHistory() async {
    return tryMethod(
      () async {
        final records = await _pb.collection(Collections.chats).getList(
              sort: '-last_active',
            );
        return records.items.map((e) => Chat.fromJson({
              ...e.data,
              'id': e.id,
              'created': e.get<String>('created'),
              'updated': e.get<String>('updated'),
            })).toList();
      },
      ChatException.new,
      'fetchChatHistory',
    );
  }

  /// Get an artifact (file) from the workspace
  Future<Uint8List> getArtifact(String path) async {
    return tryMethod(
      () async {
        final response = await _pb.send('/api/pocketcoder/artifact/$path');
        return response.bodyBytes;
      },
      ChatException.new,
      'getArtifact',
    );
  }
}
