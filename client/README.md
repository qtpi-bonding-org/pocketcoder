# PocketCoder Mobile (Flutter)

The official mobile client for PocketCoder—your local-first, privacy-focused AI coding assistant.

## 🚀 Overview

PocketCoder Mobile is a thin client designed to connect to your personal PocketCoder backend. It provides a terminal-grade interface for interacting with your AI agent, managing sessions, and overseeing automated tasks from your phone or tablet.

### Core Philosophy
- **Local-First**: Your data stays on your infrastructure.
- **Privacy-Centric**: Anonymous error reporting and secure credential storage.
- **FOSS Core**: The base application logic is fully open-source (MPL-2.0).
- **Pro Features**: Optional proprietary enhancements (Firebase Push, RevenueCat) for the App Store version.

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

This project is a monorepo managed by [Melos](https://melos.invertase.dev).

### Architecture
1. **`packages/pocketcoder_flutter`**: The core FOSS-pure logic and UI components.
2. **`packages/app`**: Proprietary integrations (Optional).
3. **`apps/app`**: The mobile application shell that assembles the pieces.

### Quick Start
```bash
# 1. Install Melos
dart pub global activate melos

# 2. Bootstrap workspace
melos bootstrap

# 3. Generate code
melos run build_gen

# 4. Run the app
cd apps/app && flutter run
```

### Purity Check
To ensure the core package remains FOSS-pure (no proprietary SDK leaks):
```bash
melos run check:purity
```

## 🛡️ License

The PocketCoder core application (`pocketcoder_flutter`) is licensed under **MPL-2.0**.
See the [LICENSE](LICENSE) file for details.

---
Built with 💚 by the [QtPi Bonding Org](https://github.com/qtpi-bonding-org).
