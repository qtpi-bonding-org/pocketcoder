# PocketCoder Mobile (Flutter)

The public Core/FOSS mobile client for PocketCoder—your local-first,
privacy-focused AI coding assistant.

## 🚀 Overview

PocketCoder Mobile is a Flutter client designed to connect to your personal
PocketCoder backend. This public checkout provides the shared FOSS core and
the FOSS/F-Droid-compatible app target (`apps/pocketcoder_foss`). The
commercial Pro shell and its `pocketcoder_pro` package live in the separate
private `pocketcoder-pro` repository and consume this workspace as a pinned
dependency.

### Core Philosophy
- **Local-First**: Your data stays on your infrastructure.
- **Privacy-Centric**: Anonymous error reporting and secure credential storage.
- **FOSS Core**: Shared application logic and the FOSS app target are kept free
  of proprietary integrations.
- **Pro boundary**: the private Pro shell adds hosted provisioning, billing,
  app-store integration, and hosted push services without adding proprietary
  dependencies to this public core.

## ✨ Features

- **Retro-Terminal UI**: A stunning green-on-black aesthetic inspired by classic computing.
- **Agent Orchestration**: Real-time streaming of agent thoughts and tool executions.
- **Sandboxed Execution**: Inspect and control the remote sandbox from your device.
- **Permission Gating**: Approve or deny sensitive AI actions (file writes, command execution) with a single tap.
- **Offline Resilience**: Robust state management via Drift/SQLite for browsing history without a connection.

## 🏗️ Technical Stack

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Bloc/Cubit](https://pub.dev/packages/flutter_bloc) with `cubit_ui_flow`
- **Database**: [Drift](https://drift.simonbinder.eu/) (High-performance reactive SQLite)
- **Networking**: PocketBase Client + DartSSH2
- **Terminal Emulator**: [xterm.dart](https://pub.dev/packages/xterm)

## 🛠️ Development

This project is a workspace managed by [Melos](https://melos.invertase.dev).

### Architecture
1. **`packages/pocketcoder_flutter`**: The core FOSS-pure logic and UI components.
2. **`apps/pocketcoder_foss`**: The public app shell for this checkout.
3. **Private Pro repository**: proprietary integrations and the commercial app
   shell, maintained separately.

### Quick Start
```bash
# 1. Install Melos
dart pub global activate melos

# 2. From client/, bootstrap the workspace
flutter pub get
melos bootstrap

# 3. Generate code
melos run build_gen

# 4. Run the public app target
melos run run_foss      # FOSS/F-Droid-compatible target
```

The private Pro repository has its own app commands and adds the deployment
and billing packages around this public core.

### Purity Check
To ensure the core package remains FOSS-pure (no proprietary SDK leaks):
```bash
melos run check:purity
```

Build the FOSS Android target independently with `melos run build_foss`.
It excludes the Pro push, billing, and deployment integrations.

## 🛡️ License

The shared FOSS core (`pocketcoder_flutter`) and FOSS app target are covered by
the client workspace's licensing terms. See [LICENSE](LICENSE) and
[README_MONOREPO.md](README_MONOREPO.md) for the workspace rules.

---
Built with 💚 by the [QtPi Bonding Org](https://github.com/qtpi-bonding-org).
