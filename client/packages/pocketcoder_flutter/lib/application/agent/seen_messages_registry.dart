import 'package:injectable/injectable.dart';

/// Tracks which Poco messages have already fully played their typewriter
/// reveal, keyed by chat id.
///
/// This lives outside [ChatCubit] deliberately: ChatCubit is DI-registered
/// as a factory (a fresh instance per chat-screen visit), so any "already
/// shown" bookkeeping stored only in its state is lost every time the user
/// leaves and re-enters a chat. This app-lifetime singleton is the thing
/// that actually survives that recreation.
@lazySingleton
class SeenMessagesRegistry {
  final Map<String, Set<String>> _seenByChat = {};

  bool hasSeen(String chatId, String messageId) =>
      _seenByChat[chatId]?.contains(messageId) ?? false;

  void markSeen(String chatId, String messageId) {
    (_seenByChat[chatId] ??= <String>{}).add(messageId);
  }

  Set<String> seenIdsFor(String chatId) =>
      Set.unmodifiable(_seenByChat[chatId] ?? const <String>{});
}
