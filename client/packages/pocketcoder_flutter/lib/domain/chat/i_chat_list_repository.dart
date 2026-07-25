import 'package:pocketcoder_flutter/domain/models/chat.dart';

abstract class IChatListRepository {
  Stream<List<Chat>> watchChats();
  Future<bool> hasAnyChats();
  Future<Chat> createChat({String? title});
  Future<void> archiveChat(String id);
  Future<void> deleteChat(String id);
}
