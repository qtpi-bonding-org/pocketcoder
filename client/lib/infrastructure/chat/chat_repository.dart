import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/chat/chat_message.dart';
import '../../domain/chat/i_chat_repository.dart';
import '../../domain/chat/chat.dart';
import '../core/collections.dart';

@LazySingleton(as: IChatRepository)
class ChatRepository implements IChatRepository {
  final PocketBase _pb;

  ChatRepository(this._pb);

  @override
  Stream<List<ChatMessage>> watchColdPipe(String chatId) async* {
    // 1. Initial Fetch
    final records = await _pb.collection(Collections.messages).getList(
          filter: 'chat = "$chatId"',
          sort: 'created',
          expand: 'chat',
        );

    List<ChatMessage> messages = records.items
        .map((r) => ChatMessage.fromJson({...r.toJson(), 'chatId': chatId}))
        .toList();

    yield messages;

    // 2. Subscribe to new messages
    final controller = StreamController<List<ChatMessage>>();

    // Initial emission
    controller.add(messages);

    final unsubscribe = await _pb.collection(Collections.messages).subscribe('*', (e) {
      if (e.action == 'create') {
        final newMsg =
            ChatMessage.fromJson({...e.record!.toJson(), 'chatId': chatId});
        messages = [...messages, newMsg];
        controller.add(messages);
      } else if (e.action == 'update') {
        final updatedMsg =
            ChatMessage.fromJson({...e.record!.toJson(), 'chatId': chatId});
        final index = messages.indexWhere((m) => m.id == updatedMsg.id);
        if (index != -1) {
          messages[index] = updatedMsg;
        } else {
          // If for some reason we missed the create, treat it as one
          messages = [...messages, updatedMsg];
        }
        controller.add(messages);
      }
    }, filter: 'chat = "$chatId"');

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

    // We subscribe to the custom 'logs' topic.
    // This requires a custom route on the backend to broadcast.
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
          controller.add(
              HotPipeEvent.system(text: (payload['text'] as String?) ?? ''));
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
    print('ChatRepo: Creating message in PB chat=$chatId content="$content"');
    try {
      await _pb.collection(Collections.messages).create(body: {
        'chat': chatId,
        'role': 'user',
        'parts': [
          {'type': 'text', 'text': content}
        ],
      });
      print('ChatRepo: Message created successfully');
    } catch (e) {
      print('ChatRepo: Failed to create message: $e');
      rethrow;
    }
  }

  @override
  Future<String> ensureChat(String title) async {
    final userId = _pb.authStore.record?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
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
    } catch (e) {
      throw Exception('Failed to ensure chat: $e');
    }
  }

  @override
  Future<String?> getOpencodeId(String chatId) async {
    try {
      final chat = await _pb.collection(Collections.chats).getOne(chatId);
      return chat.getStringValue('opencode_id');
    } catch (e) {
      print('ChatRepo: Failed to get opencode_id for $chatId: $e');
      return null;
    }
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
    try {
      final records = await _pb.collection(Collections.chats).getList(
            sort: '-last_active',
            // filter: 'user = "${_pb.authStore.record?.id}"', // Uncomment if chat history should be user-specific
          );
      return records.items.map((e) => Chat.fromJson(e.toJson())).toList();
    } catch (e) {
      print('ChatRepository: Failed to fetch chat history: $e');
      rethrow;
    }
  }
}
