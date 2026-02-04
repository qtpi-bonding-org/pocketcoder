---
trigger: always_on
---

# PocketCoder Project Guide
*Architecture, Standards, and Implementation Goals (Core Setup)*

## 🎯 Project Objective
PocketCoder is an accessible, secure, and user-friendly open-source coding assistant platform. We focus on **user ownership** and aim to provide a personal experience that is as easy to self-host as your favorite apps on Pikapods or YunoHost.

The core goal is to provide a persistent, transparent environment where an AI can assist with complex tasks while ensuring the user remains the ultimate authority, with permanent memory via a secure "Gatekeeper."

---

## 🏛️ Core Components

1.  **OpenCode (Reasoning)**: 
    *   **Role**: The primary reasoning engine.
    *   **Implementation**: Installed via `npm` (opencode-ai). 
    *   **Integration**: Connects to the backend via an open protocol (MCP), ensuring the "brain" is decoupled from the execution layer.
2.  **PocketBase (Core)**: 
    *   **Role**: The heart of the system for auth, persistence, and permission gating.
    *   **Implementation**: A lightweight Go-based backend (standard PocketBase) that defines the rules of the house.
3.  **The Sandbox (Execution Environment)**: 
    *   **Role**: A safe, isolated space where the actual work happens.
    *   **Core Tech**: Built on standard Unix tools (Tmux) to ensure reliability and visibility.
    *   **Tooling**: Every tool (Shell, Git, Browser) is hosted here to maintain clean separation of concerns.

---

## 🔑 The Gatekeeper (Intent Gating)
*   **Persistent Intent**: Every proposed action is recorded as an "Intent" in the database. This creates a readable, permanent log of the AI's journey.
*   **User Authority**: Sensitive actions (like writing files or running commands) are created as `drafts`. They require a human "signature" (authorization) before they are executed.
*   **Auditability**: By using a standard SQLite backend, the system remains transparent and inspectable by the user at any time.

---

## 📁 Repository Standards

### 1. Philosophy & Naming
*   **Humble Minimalism**: We strive for the smallest possible surface area. We favor standard, well-worn tools over complex, bespoke frameworks.
*   **Inclusive Design**: The codebase should be clear enough for anyone to contribute to or understand.
*   **Zero-Trust by Default**: The Reasoning engine is a guest in the system. It only accesses tools through the secure gatekeeper.

### 2. File Organization
*   `/connector`: The bridge between the brain and the database.
*   `/backend`: The Go source for the PocketBase instance and rules.
*   `/sandbox`: The logic for the isolated execution environment.
*   `Dockerfile.*`: Optimized, simple images designed to run anywhere.

---

## 🛠️ Implementation Standards
*   **Safety First**: We never bypass the Intent system for convenience. The gatekeeper is what makes the system trustworthy.
*   **Local-First & Portable**: We design for single-user instances. PocketCoder should feel light enough to run on a humble VPS or a home server.
*   **Clean and Modular**: We delete legacy code promptly. If a feature isn't serving the user's current needs, it doesn't belong in the core codebase.

---

## 🚀 Vision
PocketCoder is the **foundation** of personal AI engineering. We believe that professional-grade AI tools should be transparent, user-owned, and easy for everyone to use. We are building a world where the developer is always in control of the machine.
