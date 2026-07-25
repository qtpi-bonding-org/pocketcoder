class ChatListException implements Exception {
  final String message;
  final Object? cause;

  ChatListException(this.message, [this.cause]);

  @override
  String toString() => 'ChatListException: $message';
}
