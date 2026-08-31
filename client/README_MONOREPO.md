# PocketCoder Flutter Workspace

This public checkout is the **Melos-managed FOSS workspace** for PocketCoder.
The private Pro repository consumes the core package and adds its own workspace
around it; Pro packages are not expected to exist in this checkout.

## 🏗️ Structure

- **`packages/pocketcoder_flutter`**: Core logic, UI, and state management. **Must remain FOSS-pure.**
- **Private Pro repository**: proprietary SDK/container and commercial app shell
  (Firebase, RevenueCat, hosted provisioning, etc.).
- **`apps/pocketcoder_foss`**: the public app shell for this checkout.

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

The public workspace contains `apps/pocketcoder_foss` and the shared feature
package in `packages/pocketcoder_flutter`. The private Pro workspace supplies
`apps/pocketcoder` and `packages/pocketcoder_pro` separately.

## 🛠️ Essential Commands

| Command | Description |
| --- | --- |
| `melos run check:purity` | **Critical**: Verifies the core package has no proprietary leaks. |
| `melos run run_foss` | Run the FOSS/F-Droid-compatible app. |
| `melos run build_foss` | Build the FOSS/F-Droid-compatible Android debug APK. |
| `melos run test` | Run tests across all packages. |
| `melos run fix` | Apply `dart fix` to all packages in the workspace. |

## 🛡️ FOSS Purity Rules

1.  Never add proprietary SDKs (Firebase, RevenueCat, etc.) to `pocketcoder_flutter`.
2.  Keep all proprietary logic gated inside `packages/pocketcoder_pro`.
3.  Always run `melos run check:purity` before committing core changes.
