# Service & Repository Pattern

## Core Philosophy

- **Exception-Safe**: Methods should never crash unexpectedly.
- **Privacy-First**: Technical details stay in logs; user messages are generic.
- **Typed**: Use typed exceptions for expected failure modes.

## Implementation Rules

### 1. `tryMethod` Wrapper
Every public method in a Service or Repository **MUST** be wrapped in `tryMethod`.

```dart
Future<User> getUser(String id) {
  return tryMethod(
    () async => _api.fetchUser(id),
    UserException.new, // Wrapper exception factory
    'getUser', // Simple method name (no user data!)
  );
}
```

### 2. Null Safety
- **Never use `!` operator**.
- Use `?.` and `??` for valid null states.
- Use `requireNonNull` for non-negotiable data.

```dart
// BAD
final name = user!.name!; 

// GOOD
final name = requireNonNull(user?.name, 'user name', UserException.new);
```

### 3. Exception Flow

1. **Repository**: Throws `UserException("getUser failed: DioException", cause)`
2. **Cubit**: `tryOperation` catches it.
3. **Mapper**: Maps `UserException` -> `MessageKey.error('user.fetch_failed')` (generic).
4. **UI**: Displays "Unable to load user profile" (localized).

This ensures the UI never shows "DioError: Http status 503" to the user, but the logs (via `SafeExceptionCause`) contain the full stack trace.
