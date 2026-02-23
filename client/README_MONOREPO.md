# PocketCoder Flutter Workspace

This is a **Melos-managed monorepo** for the PocketCoder Flutter application. It is designed to support two distinct app versions—**FOSS (F-Droid)** and **App Store (Pro)**—using a single core logic package.

## 🏗️ Structure

- **`packages/pocketcoder_flutter`**: Core logic, UI, and state management. **Must remain FOSS-pure.**
- **`packages/pn_ntfy`**: FOSS-friendly push notification implementation (ntfy).
- **`packages/pn_fcm`**: Proprietary SDK container (Firebase, RevenueCat). Only used in the App Store version.
- **`apps/foss`**: App shell for F-Droid.
- **`apps/app`**: App shell for App Store/Play Store.

## 🚀 Getting Started

### Prerequisites

1.  **Install Melos** (if not already installed):
    ```bash
    dart pub global activate melos
    ```

### Initialization

1.  **Bootstrap the workspace**:
    This links all local packages and installs dependencies.
    ```bash
    melos bootstrap
    ```

## 🛠️ Essential Commands

| Command | Description |
| --- | --- |
| `melos run check:purity` | **Critical**: Verifies the FOSS app has no proprietary leaks. |
| `melos run build:foss` | Build the FOSS Android APK. |
| `melos run build:app` | Build the App Store/Pro Android APK. |
| `melos run test` | Run tests across all packages. |
| `melos run fix` | Apply `dart fix` to all packages in the workspace. |

## 🛡️ FOSS Purity Rules

1.  Never add proprietary SDKs (Firebase, RevenueCat, etc.) to `pocketcoder_flutter`.
2.  Keep all proprietary logic gated inside `packages/pn_fcm`.
3.  Always run `melos run check:purity` before committing changes to the FOSS app.
