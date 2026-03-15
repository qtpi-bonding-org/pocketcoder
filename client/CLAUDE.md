# PocketCoder Flutter Client

## Null Safety

**Never use `!` operator.** It is breaking code waiting to happen.

- Use `?.` and `??` for nullable values
- Use `requireNonNull` for non-negotiable data with typed exceptions
- Prefer early returns on null over force-unwrapping

```dart
// BAD
final name = user!.name!;

// GOOD
final name = requireNonNull(user?.name, 'user name', UserException.new);

// ALSO GOOD
final name = user?.name ?? 'Unknown';
```

## State Management

Cubits only (not Blocs). All cubits extend `AppCubit<T>`.

- State must extend `IUiFlowState` with `@freezed`
- State must have `UiFlowStatus status` and `Object? error`
- Use `tryOperation` in cubits (handles try-catch + loading state)
- You MUST set `status: UiFlowStatus.success` in returned state — the library does not auto-set it

## Repository / Service Pattern

- Every public method wrapped in `tryMethod`
- Typed exceptions per domain (e.g., `UserException`, `AuthException`)
- Technical details stay in logs, user messages are generic + localized

## Dependencies

- **Freezed** for immutable models & unions
- **Injectable/GetIt** for DI (`@injectable` for cubits, `@lazySingleton` for repos)
- **GoRouter** for navigation
- **cubit_ui_flow** for automatic UI feedback (toasts, loading, errors)
- **pocketbase_drift** for offline-capable PocketBase client

## Code Generation

```bash
cd client/packages/pocketcoder_flutter
dart run build_runner build --delete-conflicting-outputs
```

## Localization

Dot-notation keys mapped to camelCase ARB keys (`app.title` -> `appTitle`).
Use `MessageKey` for programmatic strings in cubits/services. Never hardcode user-facing strings.

## Architecture

- Flutter only talks to PocketBase. Everything else is downstream.
- Server URL entered once during onboarding, persisted in `FlutterSecureStorage`, used for both PocketBase API and SSH host derivation.
- SSH terminal connects to sandbox on port 2222 as `worker` user with Ed25519 key auth.
