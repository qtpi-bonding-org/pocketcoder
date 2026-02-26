# PocketCoder Mobile Shell

This is the primary application shell for the PocketCoder Mobile app.

## 🏗️ Role
This package serves as the entry point for the mobile application across all platforms (Android, iOS, macOS, Web). It is responsible for:
1.  **Platform Configuration**: Native setup for each target platform.
2.  **Service Injection**: Wiring up core services from `pocketcoder_flutter` with implementation details (including proprietary ones from `package:app`).
3.  **Bootstrapping**: Initializing the application lifecycle.

## 🛠️ Development
While most feature work happens in `packages/pocketcoder_flutter`, you run and debug the app from this directory.

```bash
flutter run
```

## 🛡️ Structure
- `lib/main.dart`: The main entry point. Initializes `get_it` and calls `bootstrap()`.
- `android/`, `ios/`, etc.: Platform-specific projects and configurations.
