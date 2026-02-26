# PocketCoder Flutter Core

This package contains the core logic, UI components, and state management for the PocketCoder Flutter application.

## 🛡️ FOSS Purity
This package is **FOSS-pure**. It must **never** depend on proprietary SDKs like Firebase, RevenueCat, or others. All interactions with such services must be defined via abstract interfaces in the `domain/` layer, with implementations injected at the app level.

## 🏗️ Architecture
We follow a variation of Clean Architecture with a focus on Bloc/Cubit for state management:

- **`lib/domain/`**: Business logic interfaces, models, and service definitions.
- **`lib/infrastructure/`**: Concrete implementations of repositories and services (FOSS-only).
- **`lib/application/`**: Cubits and state logic.
- **`lib/presentation/`**: UI widgets, screens, and styling.
- **`lib/app/`**: Application-wide setup (DI, Routing, Bootstrap).

## 🌍 Localization
Localization is handled using `.arb` files in `lib/l10n/` and the `l10n_key_resolver` package for type-safe dot-notation access.

## 🎨 Design System
The UI follows a strict terminal-inspired design system defined in `lib/presentation/core/palette.dart` and `lib/presentation/core/theme.dart`.

## 🛠️ Development
Run code generation:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## 🛡️ License
This package is licensed under **MPL-2.0**.
