# Development Guide 🛠

Welcome to the PocketCoder workbench. This document explains how I've pieced the system together and how you can run it locally for development.

## 🏗 Architecture & Leverage

PocketCoder doesn't try to reinvent the wheel. It uses a **Physical Separation of Concerns** to keep things simple and secure:

1.  **Reasoning (OpenCode)**: The "Brain." It runs in an isolated container.
2.  **Relay (Go/PocketBase)**: The "Spinal Cord." It uses PocketBase's event system to orchestrate the flow.
3.  **Proxy (Rust)**: The "Muscle." A tiny, secure bridge that translates intents into `tmux` instructions.
4.  **Sandbox (Tmux/Docker)**: The "Reality." A standard Linux environment where the actual work happens.

### Why this stack?
I chose these tools for their **leverage**:
- **Tmux**: Gives us resilient, attachable sessions for free.
- **PocketBase**: Handles auth, database, and a nice UI in a single Go binary.
- **Docker**: Provides the isolation needed to run AI-generated code safely.

## 🛠 Local Setup

### Prerequisites
- Docker & Docker Compose
- A Gemini API Key ([Get one here](https://aistudio.google.com/app/apikey))

### Steps
1.  **Prep**:
    ```bash
    git clone https://github.com/qtpi-bonding-org/pocketcoder.git
    cd pocketcoder
    cp .env.example .env
    # Add your GEMINI_API_KEY to .env
    ```
2.  **Run**:
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
