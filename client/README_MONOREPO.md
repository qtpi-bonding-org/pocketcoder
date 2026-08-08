# PocketCoder Flutter Workspace

This is a **Melos-managed monorepo** for the PocketCoder Flutter application. It uses a core logic package shared between a base FOSS foundation and proprietary additions.

## 🏗️ Structure

- **`packages/pocketcoder_flutter`**: Core logic, UI, and state management. **Must remain FOSS-pure.**
- **`packages/pocketcoder_pro`**: Proprietary SDK container (Firebase, RevenueCat, etc.).
- **`apps/pocketcoder`**: The primary PocketCoder application shell. Injects services from both packages.

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

The workspace contains both `apps/pocketcoder` (the Pro shell) and
`apps/pocketcoder_foss` (the FOSS/F-Droid-compatible target). Shared feature code lives in
`packages/pocketcoder_flutter`.

## 🛠️ Essential Commands

| Command | Description |
| --- | --- |
| `melos run check:purity` | **Critical**: Verifies the core package has no proprietary leaks. |
| `melos run run_app` | Run the Pro app. |
| `melos run run_foss` | Run the FOSS/F-Droid-compatible app. |
| `melos run run_incognito` | Run the Pro app in Chrome Incognito. |
| `melos run build_app` | Build the Pro Android debug APK. |
| `melos run build_foss` | Build the FOSS/F-Droid-compatible Android debug APK. |
| `melos run test` | Run tests across all packages. |
| `melos run fix` | Apply `dart fix` to all packages in the workspace. |

## 🛡️ FOSS Purity Rules

1.  Never add proprietary SDKs (Firebase, RevenueCat, etc.) to `pocketcoder_flutter`.
2.  Keep all proprietary logic gated inside `packages/pocketcoder_pro`.
3.  Always run `melos run check:purity` before committing core changes.
