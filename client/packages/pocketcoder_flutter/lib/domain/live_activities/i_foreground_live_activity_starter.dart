/// Pro apps may register this optional UI-facing fast-path for starting a
/// Live Activity when an observed agent run enters its running state.
///
/// The shared chat UI deliberately treats this as optional: the FOSS app does
/// not provide an iOS ActivityKit implementation.
abstract class IForegroundLiveActivityStarter {
  /// Starts the best-effort foreground Live Activity for [chatId].
  Future<void> startForChat(String chatId);
}
