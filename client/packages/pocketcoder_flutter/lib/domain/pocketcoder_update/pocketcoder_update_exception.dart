import 'pocketcoder_update_result.dart';

/// The PocketCoder update could not be attempted.
///
/// This is distinct from an updater command returning a non-zero result; see
/// [PocketCoderUpdateResult.succeeded].
class PocketCoderUpdateException implements Exception {
  const PocketCoderUpdateException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'PocketCoderUpdateException: $message';
}
