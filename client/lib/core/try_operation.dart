/// Service/Repository method wrapper for consistent exception handling.
///
/// This is the service/repository equivalent of `tryOperation` in cubits.
/// It ensures all exceptions are properly typed and wrapped with context.
///
/// ## Usage
///
/// ```dart
/// Future<Account> createAccount() {
///   return tryMethod(
///     () async {
///       final key = await _repo.getKey();
///       if (key == null) {
///         throw AccountException('Key not found');
///       }
///       return await _client.create(key);
///     },
///     AccountException.new,
///     'createAccount',
///   );
/// }
/// ```
///
/// ## Rules
///
/// - Every public method in services/repositories should use this
/// - Never use `!` operator - use explicit null checks with typed exceptions
/// - Use `?.` and `??` for null handling where null is a valid state
/// - Use simple method names (no user data) for privacy
library;

/// Privacy-safe wrapper for exception causes.
///
/// A complete diagnostic capsule that preserves all technical debugging information
/// while maintaining strict privacy boundaries. Only exposes safe type information
/// in toString() but stores complete context for debugging.
class SafeExceptionCause {
  final Type originalType;
  final Object originalException;
  final StackTrace originalStack;

  const SafeExceptionCause(
      this.originalType, this.originalException, this.originalStack);

  @override
  String toString() =>
      originalType.toString(); // Only type, no message or stack
}

/// Creates a privacy-safe error context message.
///
/// Only includes safe technical information:
/// - Method name (controlled by developers)
/// - Exception type (class name only)
///
/// Never includes user data, file paths, or sensitive information.
String _createSafeErrorContext(String methodName, Type errorType) {
  return '$methodName failed: $errorType';
}

/// Wraps service/repository methods with consistent exception handling.
///
/// - If the method throws an exception of type [E], it rethrows as-is with original stack trace
/// - If the method throws any other exception, it wraps it using [wrapException] and preserves stack trace
///
/// Parameters:
/// - [method]: The async method to execute
/// - [wrapException]: Factory to create typed exception (e.g., `MyException.new`)
/// - [methodName]: Simple method name (e.g., 'createAccount') - no user data
///
/// The [wrapException] factory should accept (String message, [Object? cause]).
///
/// Privacy Note: Only method names (controlled by developers) and exception types
/// are included in error messages. Original exceptions are wrapped in SafeExceptionCause
/// to prevent PII leakage while preserving debugging information.
Future<T> tryMethod<T, E extends Exception>(
  Future<T> Function() method,
  E Function(String message, [Object? cause]) wrapException,
  String methodName,
) async {
  try {
    return await method();
  } on E {
    rethrow; // Preserves original stack trace for typed exceptions
  } catch (e, stackTrace) {
    // Privacy-safe: Only method name and exception type in message
    final safeMessage = _createSafeErrorContext(methodName, e.runtimeType);

    // Privacy-safe diagnostic capsule: Complete debugging info with safe toString()
    final safeCause = SafeExceptionCause(e.runtimeType, e, stackTrace);

    final wrappedException = wrapException(safeMessage, safeCause);

    // Preserve the original stack trace
    Error.throwWithStackTrace(wrappedException, stackTrace);
  }
}

/// Requires a value to be non-null, throwing a typed exception if null.
///
/// Use instead of `!` operator for better error messages.
///
/// ```dart
/// final key = requireNonNull(
///   await _repo.getKey(),
///   'symmetric key',        // ← Technical label only, no user data
///   KeyException.new,
/// );
/// ```
///
/// PRIVACY RULE: The 'name' parameter must be a technical label
/// (e.g., 'ui settings', 'auth token').
/// NEVER include dynamic user data like emails, usernames, or IDs.
T requireNonNull<T, E extends Exception>(
  T? value,
  String name,
  E Function(String message, [Object? cause]) wrapException,
) {
  if (value == null) {
    throw wrapException('$name is null');
  }
  return value;
}
