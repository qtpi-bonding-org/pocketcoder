import 'dart:async';

/// Guards the CA-pin write path. Deliberately NOT pocketcoder_pro's
/// AttemptLock, and not shared code with it -- reusing AttemptLock here
/// would be a bug: the pin fetch is spawned from inside an operation that is
/// STILL HOLDING AttemptLock, so re-acquiring it for the write blocks
/// until the attempt reaches a terminal status, by which point the
/// write's own "is this still current" gate has already gone false --
/// silently discarding the pin on every successful deploy. A separate
/// mutex that never contends with AttemptLock is the fix.
class CaPinMutex {
  Future<void> _tail = Future<void>.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        completer.complete();
      }
    });
  }
}
