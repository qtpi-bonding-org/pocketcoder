import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/communication/i_chat_repository.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:flutter_aeroform/support/extensions/cubit_ui_flow_extension.dart';

@injectable
class ChatListCubit extends AppCubit<ChatListState> {
  final IChatRepository _repository;

  ChatListCubit(this._repository) : super(const ChatListState());

  Future<void> loadChats() async {
    await tryOperation(() async {
      final chats = await _repository.fetchChatHistory();
      return state.copyWith(
        status: UiFlowStatus.success,
        chats: chats,
      );
    }, emitLoading: true);
  }
}
