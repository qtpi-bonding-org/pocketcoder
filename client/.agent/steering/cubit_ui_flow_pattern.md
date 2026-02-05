# Cubit UI Flow Pattern Guide

## How It Works

Automatic UI feedback system: **State → Message Mapping → Localization → UI**

```
UiFlowStatus.success → 'template.saved' → "Template saved!" → Green Toast
```

## Basic Usage

### 1. State with IUiFlowState
```dart
@freezed
class TemplateState with _$TemplateState implements IUiFlowState {
  const factory TemplateState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    TemplateOperation? lastOperation, // ← Context for messages
  }) = _TemplateState;
}
```

### 2. Cubit with tryOperation
```dart
class TemplateCubit extends AppCubit<TemplateState> {
  Future<void> saveTemplate() async {
    await tryOperation(() async {
      await repository.save();
      return state.copyWith(
        status: UiFlowStatus.success,  // ⚠️ REQUIRED - must set explicitly!
        lastOperation: TemplateOperation.save,
      );
    }, emitLoading: true); // ← Automatic loading overlay
  }
}
```

> ⚠️ **Critical:** You MUST set `status: UiFlowStatus.success` in the returned state. The library does NOT auto-set success status - forgetting this will leave the UI stuck in loading state.

### 3. Message Mapper
```dart
class TemplateMessageMapper implements IStateMessageMapper<TemplateState> {
  @override
  MessageKey? map(TemplateState state) {
    if (state.status.isSuccess && state.lastOperation != null) {
      return switch (state.lastOperation!) {
        TemplateOperation.save => MessageKey.success('template.saved'),
        TemplateOperation.delete => MessageKey.success('template.deleted'),
      };
    }
    return null; // Use global exception mapping for errors
  }
}
```

### 4. Localization Keys

Localization is handled automatically by the generated `L10nKeyResolver`. Keys use dot-notation that maps to camelCase ARB keys:

| Dot Key | ARB Key |
|---------|---------|
| `template.saved` | `templateSaved` |
| `error.network` | `errorNetwork` |
| `error.generic` | `errorGeneric` |

The `AppLocalizationService` uses the generated resolver - no manual switch statements needed.

To add new keys:
1. Add to `lib/l10n/app_en.arb` (camelCase)
2. Run `dart run build_runner build --delete-conflicting-outputs`
3. Use dot-notation in your code

### 5. UI Integration
```dart
UiFlowStateListener<TemplateCubit, TemplateState>(
  mapper: getIt<TemplateMessageMapper>(),
  child: BlocBuilder<TemplateCubit, TemplateState>(
    builder: (context, state) {
      // Just render data - UI feedback is automatic!
      return ListView.builder(/* ... */);
    },
  ),
)
```

## What You Get

- **Automatic loading overlays** when `state.isLoading`
- **Automatic error toasts** from exception mapping
- **Automatic success messages** from state mapping
- **Consistent UX** across all features
- **Clean separation** of business logic and UI
