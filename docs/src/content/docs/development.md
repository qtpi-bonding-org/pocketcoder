---
title: Development
description: How to set up and build PocketCoder locally.
head: []
---


This document provides instructions for setting up a local development environment and running the PocketCoder test suite.

## Prerequisites

- **Docker & Docker Compose**: Core for orchestrating all services.
- **Go 1.22+**: For the `pocketbase` backend.
- **Node.js 20+**: For the `relay` services.
- **Rust**: For the `proxy` service.
- **Flutter**: For the `client` app.
- **OpenCode**: The reasoning binary (configured in `docker-compose.yml`).

---

## 1. Initial Setup

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/qtpi-bonding-org/pocketcoder.git
    cd pocketcoder
    ```

2.  **Configure Environment**:
    Copy `.env.example` to `.env` and fill in your details (PocketBase passwords, OpenCode keys, etc.).
    ```bash
    cp .env.example .env
    ```

3.  **Start Services**:
    ```bash
    docker-compose up -d --build
    ```

---

## 2. Service Development

### Backend (`pocketbase`)
The backend is a Go application using the PocketBase library.
- **Location**: `/backend`
- **Build**: `cd backend && go build -o pocketbase main.go`
- **Migrations**: New migrations should be placed in `backend/pb_migrations`. They are applied automatically on startup.

### Relay (`relay`)
The Relay handles communication and real-time syncing.
- **Location**: `/relay`
- **Main Script**: `chat_relay.mjs`
- **SSH Sync**: `sync_ssh_keys.mjs`
- **Run Locally**: `cd relay && npm install && node chat_relay.mjs`

### Proxy (`proxy`)
A high-performance Rust proxy for TMUX execution.
- **Location**: `/proxy`
- **Build**: `cd proxy && cargo build`

---

## 3. Testing

PocketCoder includes a comprehensive integration test suite that validates the "Sovereign Loop".

### Running All Tests
From the project root:
```bash
./test/run_all_tests.sh
```

This will:
1.  Verify service health.
2.  Run the **Permission Flow** test (User -> Relay -> PB Whitelist / Manual Auth -> OpenCode -> Sandbox).
3.  Run the **SSH Integration** test (PB SSH Key -> Relay Sync -> Sandbox authorized_keys -> SSH connect).

### Debugging Tools
- **Relay Access Check**: `node relay/check_relay_access.mjs` (Verifies Relay-PocketBase connection).
- **Service Logs**: `docker-compose logs -f [service_name]`

---

## 4. Architecture Standards

- **Zero-Trust**: Never bypass the PocketBase permission endpoint.
- **Isolation**: Commands MUST run in the Sandbox via the Proxy.
- **Visibility**: All AI intents MUST be recorded in the `permissions` collection.

## 5. Documentation

The documentation is built with Astro and Starlight. It runs in a separate container to isolate the build dependencies.

### Running Docs
To start the documentation server:
```bash
docker-compose -f docker-compose.docs.yml up
```
The site will be available at `http://localhost:4321`.
