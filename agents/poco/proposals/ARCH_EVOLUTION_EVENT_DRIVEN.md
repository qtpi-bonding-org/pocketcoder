# Multi-Agent Coordination: The Pulse & Reflex Architecture

## 🎯 Objective
Transition the PocketCoder nervous system from a **Synchronous/Blocking** model to an **Event-Driven/Pulse-based** architecture. This shift will fix race conditions in message batching, eliminate 30-second timeouts during delegation, and enable Poco to coordinate multiple sub-agents without "holding his breath."

---

## 🏛️ Phase 1: Relay Simplification (The Nervous System)
**Goal:** Remove turn-management intelligence from the Go Relay and defer it to the OpenCode engine.

### Current Problem
The Go Relay tries to "lock" turns in PocketBase. When messages arrive too fast, it creates race conditions, leading to "Double-Typing" in the terminal and desynced database states.

### Implementation Tasks
- **[Relay/Go] Remove Turn Locking**: Delete the complex `turn == assistant` check and manual batching in `messages.go`. The Relay should send messages to OpenCode as fast as the user sends them.
- **[Relay/Go] Stream Consumption**: Instead of waiting for a 30s HTTP response, the Relay will listen to the OpenCode `/event` SSE stream. 
- **[Relay/Go] Pulse Syncing**: As pulses (thinking, tool-calls, text) arrive over the stream, the Relay updates the PocketBase records immediately.
- **[Brain/OpenCode] Native Queueing**: OpenCode will use its internal `loop()` to handle incoming messages sequentially, ensuring no terminal collisions occur.

---

## 🏛️ Phase 2: The Reflex Arc (The Body-Brain Bridge)
**Goal:** Enable sub-agents in the Sandbox to "nudge" the Brain (Poco) without exposing the database or breaking network isolation.

### The Problem
Sub-agents work in the isolated Sandbox. When they finish, they type into Poco's terminal, but the Brain (in the `opencode` container) is "asleep" and doesn't see it. The Relay doesn't know anything happened, so it never "wakes up" the Brain.

### Implementation Tasks (The Reflex Chain)
1. **[Muscle/Proxy] Sensation**: Add a `/notify` endpoint to the Rust Proxy. CAO (Sub-agent) hits this when its task is `COMPLETED`.
2. **[Brain/OpenCode] Reflex Trigger**: OpenCode receives the notification and emits a `payload.type = "activity"` event over the global SSE firehose.
3. **[Spine/Relay] Pulse Detection**: The Relay hears the `activity` signal on the "Radio" (SSE stream). 
4. **[Spine/Relay] Ingestion**: The Relay fetches the final output from the Proxy (`/exec?cmd=cat_output`), creates a new message in PocketBase, and flips the turn. 
5. **[Brain/OpenCode] Awakening**: Since a new message appeared in the ledger, the system triggers Poco's next turn. He reads the sub-agent's report and finishes his coordinating task.

---

## 🛡️ Security & Integrity
- **Air-Gap Intact**: The Sandbox remains completely blind to PocketBase. It only knows how to talk to the local Proxy.
- **Permanent Ledger**: No conversation happens "off-record." Every signal from the Body is ingested by the Relay and recorded in the PocketBase Sovereign Ledger for user audit.
- **Turn Sovereignty**: The Relay remains the ultimate "Traffic Controller," ensuring events are processed in the correct order.

---

## 🚀 Vision: The Socket-Nervous System (Future)
As a final evolution, the system can move from HTTP/SSE to **WebSockets** or **Unix Sockets**, enabling multi-agent coordination that feels truly instantaneous and biological.
