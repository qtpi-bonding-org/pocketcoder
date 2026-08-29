import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions/chat_list_exception.dart';
import 'package:pocketcoder_flutter/domain/models/chat.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'chat_dao.dart';

@LazySingleton(as: IChatListRepository)
class ChatListRepository implements IChatListRepository {
  final ChatDao _dao;
  final IAuthRepository _auth;

  ChatListRepository(this._dao, this._auth);

  @override
  Stream<List<Chat>> watchChats() {
    return _dao.watch(filter: 'archived != true', sort: '-last_active');
  }

  @override
  Future<bool> hasAnyChats() {
    return tryMethod(
      () async {
        final chats = await _dao.getFullList(
          filter: 'archived != true',
          requestPolicy: RequestPolicy.networkOnly,
        );
        return chats.isNotEmpty;
      },
      ChatListException.new,
      'hasAnyChats',
    );
  }

  @override
  Future<Chat> createChat({
    String? title,
    String? harness,
    String? harnessModelOverride,
    String? ollamaModelOverride,
    List<String>? workspaceOverride,
  }) {
    return tryMethod(
      () async {
        final data = <String, dynamic>{
          'title': title ?? 'New Chat',
          'user': _auth.currentUserId,
        };
        if (harness != null) data['harness'] = harness;
        if (harnessModelOverride != null) {
          data['harness_model_override'] = harnessModelOverride;
        }
        if (ollamaModelOverride != null) {
          data['ollama_model_override'] = ollamaModelOverride;
        }
        if (workspaceOverride != null) {
          data['workspace_override'] = workspaceOverride;
        }
        return _dao.save(null, data);
      },
      ChatListException.new,
      'createChat',
    );
  }

  @override
  Future<void> archiveChat(String id) {
    return tryMethod(
      () async {
        await _dao.save(id, {'archived': true});
      },
      ChatListException.new,
      'archiveChat',
    );
  }

  @override
  Future<void> deleteChat(String id) {
    return tryMethod(
      () async {
        await _dao.delete(id);
      },
      ChatListException.new,
      'deleteChat',
    );
  }

  @override
  Stream<Chat?> watchChat(String id) {
    return _dao
        .watch(filter: 'id = "$id"')
        .map((chats) => chats.isEmpty ? null : chats.first);
  }

  @override
  Future<void> setMonitored(String id, bool monitored) {
    return tryMethod(
      () async {
        await _dao.save(id, {'monitored': monitored});
      },
      ChatListException.new,
      'setMonitored',
    );
  }
}
