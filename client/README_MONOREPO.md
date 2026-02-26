# PocketCoder Flutter Workspace

This is a **Melos-managed monorepo** for the PocketCoder Flutter application. It uses a core logic package shared between a base FOSS foundation and proprietary additions.

## 🏗️ Structure

- **`packages/pocketcoder_flutter`**: Core logic, UI, and state management. **Must remain FOSS-pure.**
- **`packages/app`**: Proprietary SDK container (Firebase, RevenueCat, etc.).
- **`apps/app`**: The primary PocketCoder application shell. Injects services from both packages.

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
| `melos run check:purity` | **Critical**: Verifies the core package has no proprietary leaks. |
| `melos run build:app` | Build the Mobile Android APK. |
| `melos run test` | Run tests across all packages. |
| `melos run fix` | Apply `dart fix` to all packages in the workspace. |

## 🛡️ FOSS Purity Rules

1.  Never add proprietary SDKs (Firebase, RevenueCat, etc.) to `pocketcoder_flutter`.
2.  Keep all proprietary logic gated inside `packages/app`.
3.  Always run `melos run check:purity` before committing core changes.
