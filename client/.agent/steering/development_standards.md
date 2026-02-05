# Development Standards

## Required Libraries

- **Freezed**: Immutable models & unions
- **Cubit UI Flow**: Standard state management & UI feedback
- **Injectable/GetIt**: Dependency injection
- **GoRouter**: Navigation
- **Flutter Color Palette**: Theming
- **L10n Key Resolver**: Localization

## Code Generation

Run build runner to generate code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Watch mode for development:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

## State Management

We use **Cubits** (not Blocs) for simplicity and reduced boilerplate. All Cubits must extend `AppCubit`.

### State Rules
1. Must extend `IUiFlowState` (from `cubit_ui_flow`)
2. Must use `@freezed`
3. Must define `UiFlowStatus status`
4. Must define `Object? error`

```dart
@freezed
class MyState with _$MyState implements IUiFlowState {
  const factory MyState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    // ... other data
  }) = _MyState;
}
```

### Cubit Implementation
```dart
@injectable
class MyCubit extends AppCubit<MyState> { // extend AppCubit
  MyCubit(this._repo) : super(const MyState());

  final IMyRepository _repo;

  Future<void> loadData() async {
    // tryOperation handles try-catch, error mapping, and loading status
    await tryOperation(() async {
      final data = await _repo.fetchData();
      // Only emit success - errors are caught automatically
      return state.copyWith(
        status: UiFlowStatus.success, 
        data: data,
      );
    });
  }
}
```

## Dependency Injection

Use `@injectable` annotations.

- **Services/Repositories**: `@singleton` or `@lazySingleton`
- **Cubits**: `@injectable`
- **Modules**: separate logic in `@module` classes for 3rd party types

## Localization

Use dot.notation keys mapped to camelCase ARB keys.

- `app.title` -> `appTitle`
- `error.network` -> `errorNetwork`

Always use `MessageKey` for programmatic strings (in Cubits/Services).
Never hardcode user-facing strings in logic classes.

## Error Handling

See `services_repository_pattern.md` for details.
- Use `tryMethod` in repositories/services
- Use `tryOperation` in Cubits
- Never use `!` operator
