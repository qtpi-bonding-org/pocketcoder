# Development Guide 🛠

Welcome to the PocketCoder assembly line. This document provides a deeper dive into the architecture and setup for developers.

## 🏗 High-Level Architecture

PocketCoder follows a **Physical Separation of Concerns**:

1.  **Reasoning (OpenCode)**: The "Brain." It runs in a container with a proxied shell.
2.  **Relay (Go/PocketBase)**: The "Spinal Cord." It listens to PocketBase events and orchestrates the flow.
3.  **Proxy (Rust)**: The "Muscle." A secure, minimal bridge that translates high-level intents into `tmux` instructions.
4.  **Sandbox (Tmux/Docker)**: The "Reality." An isolated Linux environment where files are written and commands are executed.

## 🛠 Local Setup

### Prerequisites
- Docker & Docker Compose
- A Gemini API Key ([Get one here](https://aistudio.google.com/app/apikey))

### Steps
1.  **Clone and Prep**:
    ```bash
    git clone https://github.com/qtpi-bonding/pocketcoder.git
    cd pocketcoder
    cp .env.example .env
    # Edit .env and enter your GEMINI_API_KEY
    ```
2.  **Spin up the Foundry**:
    ```bash
    docker-compose up -d --build
    ```
3.  **Bootstrap PocketBase**:
    Access `http://localhost:8090/_/` and follow the auto-migration logs to ensure the schema is ready.

## 🧪 Testing

We rely heavily on **Integration Tests** to verify the "Sovereign Loop."

```bash
# Run the full test suite
./test/run_all_tests.sh
```

Tests cover:
- **SSH Key Sync**: Ensures keys added to DB reach the sandbox.
- **Permission Flow**: Validates the "Always Ask" Gatekeeper.
- **Batching**: Tests turn-based conversation handling.
- **FS Serving**: Verifies the artifact serving API.

## 📁 Repository Structure

- `backend/`: Go source for the PocketBase instance and custom hooks.
- `proxy/`: Rust implementation of the secure shell proxy.
- `sandbox/`: Docker configuration and entrypoint for the isolated environment.
- `client/`: (Optional) Flutter application source.
- `docs/`: Starlight-based documentation site.

## 🛡 Security Notes

- **The /workspace Volume**: This is the shared source of truth. It is mounted in the Sandbox (Read/Write), the Proxy (indirectly via tmux), and OpenCode (Read/Write).
- **Hooks**: All sensitive updates (like making an action 'authorized') are handled via PocketBase Go hooks for auditability.
