# Contributing to PocketCoder 🦅

Thank you for your interest in contributing to PocketCoder! We are building an accessible, secure, and user-friendly open-source coding assistant platform. We value **sovereignty**, **transparency**, and **minimalism**.

## 🏛 Core Philosophy

*   **Humble Minimalism**: We favor standard, well-worn tools over complex, bespoke frameworks. We aim for a small, auditable surface area.
*   **Zero-Trust by Default**: The reasoning engine (OpenCode) is a guest. It never touches your system except through the secure Gatekeeper (PocketBase Hooks) and the isolated Sandbox.
*   **Auditability**: Every intent and action must be recorded and inspectable by the user.

## 🚀 How to Contribute

1.  **Report Bugs**: Open an issue with a clear description and steps to reproduce.
2.  **Suggest Features**: Share your ideas! We prioritize features that enhance user ownership and safety.
3.  **Submit Pull Requests**:
    *   Keep PRs small and focused.
    *   Follow the existing architectural patterns.
    *   Ensure all tests pass (`./test/run_all_tests.sh`).

## 🛠 Development Workflow

1.  **Setup**: Follow the guide in `DEVELOPMENT.md`.
2.  **Branching**: Use descriptive branch names (e.g., `feature/ssh-sync`, `fix/permission-gate`).
3.  **Code Style**: 
    *   **Go**: Run `go fmt` and `go vet`.
    *   **Architecture**: Logic should be decentralized into `internal/` packages. Keep `main.go` thin.
4.  **Testing**: Any new feature should ideally include an integration test in the `test/` directory.

## 🛡 Security First

If you discover a security vulnerability, please do NOT open a public issue. Instead, report it privately to the maintainers (see SECURITY.md).

## 📜 License

By contributing to PocketCoder, you agree that your contributions will be licensed under the **GNU Affero General Public License v3.0 (AGPLv3)**.
