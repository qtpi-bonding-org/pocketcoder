# Contributing to PocketCoder 🦅

Thanks for checking out PocketCoder! I'm building this as a way to explore how we can live safely with AI agents. I value **sovereignty**, **transparency**, and **minimalism**.

## 🏛 Core Philosophy

*   **Sovereign Simplicity**: I favor standard, well-worn tools over complex, bespoke frameworks. Small surface area = more trust.
*   **Zero-Trust by Default**: The reasoning engine (OpenCode) is a guest. It only interacts with the world through the "Gatekeeper" (PocketBase) and an isolated Sandbox.
*   **Auditability**: Every intent and action is recorded in a way that you can easily inspect.

## 🚀 How to Help

1.  **Open Issues**: If you find a bug or have a suggestion, please open an issue! As a solo dev, I might not get to it immediately, but I do read them all.
2.  **Discussions**: Share how you're using PocketCoder or what you'd like to see next.
3.  **Pull Requests**:
    *   Documentation and test-only pull requests are welcome when they are small and focused.
    *   Code contributions require a separate contributor agreement with Qtpi Bonding LLC before they can be accepted. This preserves the ability to distribute PocketCoder under both the AGPL and commercial app-store terms.
    *   Large, sweeping refactors are hard for me to review alone.
    *   Ensure all tests pass (`./tests/run-tests.sh`).

## 🛠 Development Flow

1.  **Setup**: Check out `README.md` and `CLAUDE.md`.
2.  **Style**:
    *   **Go**: Logic should be decentralized into `internal/` packages. Keep `main.go` thin.
    *   **Philosophy**: If a feature can be solved with a standard Unix tool (like `grep` or `tmux`), let's use that instead of writing new code.

## 🛡 Security First

If you discover a security vulnerability, please do NOT open a public issue. Instead, report it privately to the maintainers (see SECURITY.md).

## 📜 License

Accepted public contributions are licensed under **AGPL-3.0-or-later**. Code
contributions additionally require the contributor agreement described above;
opening a pull request by itself does not transfer or relicense your copyright.
