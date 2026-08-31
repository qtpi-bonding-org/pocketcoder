import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/chat/i_chat_list_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'chat_list_state.dart';

@injectable
class ChatListCubit extends AppCubit<ChatListState> {
  ChatListCubit(this._repo) : super(const ChatListState());

  final IChatListRepository _repo;

  StreamSubscription? _chatsSub;
  bool _autoCreateChecked = false;

  @override
  Future<void> close() {
    _chatsSub?.cancel();
    return super.close();
  }

  /// Subscribes to the repository's live chat-list stream. Mirrors
  /// `AgentConfigCubit.watchAll`: `watchChats()` returns a `Stream`, not a
  /// `Future`, so we listen directly instead of going through
  /// `tryOperation`, explicitly emitting `UiFlowStatus.success`/`failure`
  /// on every emission (the library does not auto-set those).
  ///
  /// Also explicitly clears `lastCreatedChatId` on every list emission —
  /// `copyWith` leaves unspecified fields untouched, so without this the
  /// one-shot navigation signal from `createAndOpen()`/
  /// `checkEmptyAndMaybeAutoCreate()` would linger in state indefinitely.
  void watchChats() {
    _chatsSub?.cancel();
    _chatsSub = _repo.watchChats().listen(
          (chats) => emit(state.copyWith(
            chats: chats,
            status: UiFlowStatus.success,
            lastCreatedChatId: null,
          )),
          onError: (Object e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );
  }

  Future<void> createAndOpen({
    String? title,
    String? harness,
    String? harnessModelOverride,
    String? ollamaModelOverride,
    List<String>? workspaceOverride,
  }) =>
      tryOperation(() async {
        final chat = await _repo.createChat(
          title: title,
          harness: harness,
          harnessModelOverride: harnessModelOverride,
          ollamaModelOverride: ollamaModelOverride,
          workspaceOverride: workspaceOverride,
        );
        return state.copyWith(
          status: UiFlowStatus.success,
          error: null,
          lastCreatedChatId: chat.id,
        );
      });

  Future<void> archive(String id) => tryOperation(() async {
        await _repo.archiveChat(id);
        return createSuccessState();
      });

  Future<void> delete(String id) => tryOperation(() async {
        await _repo.deleteChat(id);
        return createSuccessState();
      });

  /// Decides, authoritatively, whether this user needs their first chat
  /// auto-created. Deliberately independent of whatever `watchChats()` has
  /// emitted — a cache-only "chats.isEmpty" check would spuriously
  /// double-create a chat for a returning user whose local drift cache is
  /// cold (e.g. fresh install) but who has real chats server-side.
  ///
  /// Guarded to run at most once per cubit lifetime via [_autoCreateChecked]
  /// -- the cubit is an app-lifetime instance provided at the app root, but
  /// the screen that calls this (ChatListAdapter) mounts a fresh adapter
  /// every time it's re-entered, so a call-site-only guard would re-run this
  /// on every visit. Without this, a user who deletes their only chat and
  /// returns to the (now genuinely empty) chat list would silently get a
  /// new one auto-created for them every time — the app could never
  /// actually show an empty chat list.
  Future<void> checkEmptyAndMaybeAutoCreate() async {
    if (_autoCreateChecked) return;
    _autoCreateChecked = true;
    await tryOperation(() async {
      final hasAny = await _repo.hasAnyChats();
      if (hasAny) {
        return state.copyWith(status: UiFlowStatus.success, error: null);
      }
      final chat = await _repo.createChat();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        lastCreatedChatId: chat.id,
      );
    });
  }
}
