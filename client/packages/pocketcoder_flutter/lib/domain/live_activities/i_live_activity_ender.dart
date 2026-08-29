/// Pro apps may register this optional UI-facing handler for ending a Live
/// Activity when a user stops observing a chat.
///
/// The shared chat UI deliberately treats this as optional: the FOSS app does
/// not provide an iOS ActivityKit implementation.
abstract class ILiveActivityEnder {
  /// Ends the currently active Live Activity for [chatId] on this device, if
  /// one exists.
  Future<void> endForChat(String chatId);
}
