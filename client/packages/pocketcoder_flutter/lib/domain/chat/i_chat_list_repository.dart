import 'package:pocketcoder_flutter/domain/models/chat.dart';

abstract class IChatListRepository {
  Stream<List<Chat>> watchChats();
  Future<bool> hasAnyChats();
  Future<Chat> createChat({
    String? title,
    String? harness,
    String? harnessModelOverride,
    String? ollamaModelOverride,
    List<String>? workspaceOverride,
  });
  Future<void> archiveChat(String id);
  Future<void> deleteChat(String id);

  /// Streams [id]'s own record (single-element list filtered to it), so a
  /// screen watching one chat's `monitored` flag sees external changes
  /// (e.g. the archive-triggered auto-unmonitor in the server hook)
  /// without a manual refetch.
  Stream<Chat?> watchChat(String id);

  /// Sets whether [id] should get a Live Activity started for it
  /// automatically (including when no device is in the foreground, via
  /// server-side push-to-start) the next time a run starts on it.
  Future<void> setMonitored(String id, bool monitored);
}
