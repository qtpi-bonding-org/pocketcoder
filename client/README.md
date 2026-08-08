# PocketCoder Mobile (Flutter)

The official mobile client for PocketCoder—your local-first, privacy-focused AI coding assistant.

## 🚀 Overview

PocketCoder Mobile is a Flutter client designed to connect to your personal
PocketCoder backend. The workspace provides a shared FOSS core plus two app
targets: the Pro shell (`apps/pocketcoder`) and the FOSS/F-Droid-compatible app
(`apps/pocketcoder_foss`).

### Core Philosophy
- **Local-First**: Your data stays on your infrastructure.
- **Privacy-Centric**: Anonymous error reporting and secure credential storage.
- **FOSS Core**: Shared application logic and the FOSS app target are kept free
  of proprietary integrations.
- **Pro Features**: The Pro shell adds Firebase push, RevenueCat billing, and
  deployment integrations.

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
2. **`packages/pocketcoder_pro`**: Proprietary integrations (Optional).
3. **`apps/pocketcoder`**: The mobile application shell that assembles the pieces.

### Quick Start
```bash
# 1. Install Melos
dart pub global activate melos

# 2. From client/, bootstrap the workspace
flutter pub get
melos bootstrap

# 3. Generate code
melos run build_gen

# 4. Run an app target
melos run run_app       # Pro
melos run run_foss      # FOSS/F-Droid-compatible target
melos run run_incognito # Pro in Chrome Incognito
```

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
