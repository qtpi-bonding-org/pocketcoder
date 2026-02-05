# Flutter Starter Template

A robust, production-ready Flutter project template based on the Quanitya architecture. This template provides a solid foundation with best practices for state management, dependency injection, theming, localization, and error handling.

## Features

### 🏗️ **Architecture**
- **State Management**: Cubit-based architecture with `cubit_ui_flow` for automatic UI feedback
- **Dependency Injection**: `injectable` + `get_it` for clean, testable code
- **Privacy-First Error Handling**: `flutter_error_privserver` for secure error reporting
- **Type-Safe Navigation**: `go_router` with centralized route management

### 🎨 **Design System**
- **Automatic Dark Mode**: `flutter_color_palette` with symmetric palette generation
- **Responsive Sizing**: `UiScaler` for consistent UI across devices
- **Design Tokens**: Centralized spacing, typography, and color primitives

### 🌍 **Localization**
- **Dot-Notation Keys**: `l10n_key_resolver` for clean, maintainable translations
- **Type-Safe**: Generated localization with compile-time safety

### 📋 **Code Generation**
- **Freezed**: Immutable models with copyWith and unions
- **Injectable**: Automatic dependency injection setup
- **Build Runner**: Integrated code generation workflow

## Getting Started

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher

### Installation

1. **Clone or use this template**
   ```bash
   # If using as a GitHub template
   # Click "Use this template" button on GitHub
   
   # Or clone directly
   git clone <your-repo-url>
   cd flutter_starter_template
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Renaming the App

Use the included rename script to customize the app name and package identifier:

```bash
# Make the script executable (first time only)
chmod +x rename_app.sh

# Rename with just an app name (package ID auto-generated)
./rename_app.sh "My Cool App"

# Rename with custom package identifier
./rename_app.sh "My Cool App" "com.mycompany.mycoolapp"
```

The script updates:
- ✅ `pubspec.yaml` package name
- ✅ All Dart import statements
- ✅ Android package ID, app label, and Kotlin path
- ✅ iOS bundle identifier and display name
- ✅ macOS bundle identifier and display name
- ✅ Linux binary name and application ID
- ✅ Windows binary name
- ✅ Web title and manifest

After renaming, run:
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

## Project Structure

```
lib/
├── app/
│   ├── app.dart              # Root MaterialApp widget
│   └── bootstrap.dart        # Centralized initialization
├── app_router.dart           # GoRouter configuration
├── core/
│   └── try_operation.dart    # Exception handling utilities
├── design_system/
│   ├── primitives/           # Colors, fonts, sizes
│   └── theme/                # Theme configuration
├── infrastructure/
│   └── feedback/             # Localization & exception mapping
├── l10n/                     # Localization files
├── support/
│   └── extensions/           # Base Cubit class
└── main.dart                 # Entry point

.agent/
└── steering/                 # Development standards & patterns
```

## Development

### Code Generation

Run code generation in watch mode during development:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Adding Localization Keys

1. Add keys to `lib/l10n/app_en.arb` in camelCase:
   ```json
   {
     "errorNetwork": "Network error occurred"
   }
   ```

2. Use dot-notation in code:
   ```dart
   MessageKey.error('error.network')
   ```

3. Run code generation to update the resolver

### Creating a New Feature

1. **Create State** (using Freezed):
   ```dart
   @freezed
   class MyFeatureState with _$MyFeatureState implements IUiFlowState {
     const factory MyFeatureState({
       @Default(UiFlowStatus.idle) UiFlowStatus status,
       Object? error,
       // ... your data
     }) = _MyFeatureState;
   }
   ```

2. **Create Cubit** (extending AppCubit):
   ```dart
   @injectable
   class MyFeatureCubit extends AppCubit<MyFeatureState> {
     MyFeatureCubit() : super(const MyFeatureState());
     
     Future<void> loadData() async {
       await tryOperation(() async {
         // Your logic here
         return state.copyWith(status: UiFlowStatus.success);
       });
     }
   }
   ```

3. **Register in DI**: The `@injectable` annotation handles this automatically

## Architecture Patterns

This template follows several key patterns documented in `.agent/steering/`:

- **Cubit UI Flow Pattern**: Automatic state-to-UI feedback
- **Service/Repository Pattern**: Privacy-safe exception handling
- **Development Standards**: Code generation, DI, and localization guidelines

## Testing

Run tests:
```bash
flutter test
```

## Customization

### Changing App Name

1. Update `name` in `pubspec.yaml`
2. Update `CFBundleName` in iOS `Info.plist`
3. Update `android:label` in Android `AndroidManifest.xml`

### Changing Package Name

Use the `change_app_package_name` package or manually update:
- iOS: `ios/Runner.xcodeproj/project.pbxproj`
- Android: `android/app/build.gradle`

### Customizing Theme

Edit `lib/design_system/primitives/app_palette.dart` to change colors. Dark mode is generated automatically.

## License

This template is provided as-is for use in your projects.

## Credits

Based on the Quanitya architecture and custom libraries:
- `cubit_ui_flow`
- `flutter_error_privserver`
- `flutter_color_palette`
- `l10n_key_resolver`
