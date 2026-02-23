# 🧠 PocketCoder: The Sovereign Evolution (Brainstorming)

This document tracks our vision for moving PocketCoder from a "Mobile Claude Code" to a truly **Sovereign Agentic Coordinator**.

---

## 🎯 The "More Than a Chatbot" Vision
Currently, we have the foundation: A secure sandbox, a gated relay, and a local ledger. Now we need to define the **Cognitive Architecture**.

### 1. The Memory Hierarchy (Identity vs. Context)
We need to solve the "Persistence vs. Poisoning" problem.
- **The Soul (`Poco.md`)**: Static identity, core safety rules, and project anatomy. High Trust.
- **SOPs (Shared Orders)**: User-signed rules for specific workflows (e.g., "Always lint before commit"). Legal Trust.
- **Observations (Notes to Self)**: Pattern recognition and user preferences. **Default: OFF**. Advisory only.
- **The Ledger (Active State)**: A "Save Game" for long-running tasks. Tells Poco exactly what step he is on.

### 2. Continuity & The "Heartbeat" Loop
How Poco stays awake during complex builds without the User babysitting.
- **Managed Loops**: Poco creates a list of "Intents" for a task. 
- **Auto-Followups**: If a task is $40\%$ done, Poco creates a "Follow-up" intent in the database.
- **Idle Checks**: If Poco is waiting for the user, he "sleeps." If he realizes a background task is done (via heartbeat), he notifies the Commander.
- **Broad Goals (The 'Initiative')**: High-level, long-term objectives (e.g., "Make the backend 2x faster," "Improve sandbox isolation"). 
  - **Generative Proactivity**: If there are no active tasks, Poco uses the Heartbeat to look at the "Broad Goals" and "Observations" to *generatively* propose new experiments or audits. he doesn't just sit there; he scouts for improvements.

### 3. Safety & Sovereignty (The Gated Soul)
- **Zero-Trust Memory**: Poco treats his own "Observations" as rumors. He must ask: *"I noticed X, should I propose Y?"*
- **SOP Sign-off**: New SOPs are proposed as drafts. They only enter the "Standing Orders" when signed.
- **The "Bunker" Firewall**: The LLM is an "untrusted telepathic consultant." It never sees the full database—only what the Relay filters for the current task.

### 4. Identity Architecture (OIC vs. Scraper)
- **Role**: Poco is the **Officer in Charge (OIC)**. 
- **Sub-Agents**: Poco doesn't "scrape the web" himself; he deploys an "OpenClaw-style" sub-agent into the Sandbox to do it, then audits the result.
- **Anatomy Awareness**: He knows his "Body" is the Relay (Nervous System), Proxy (Immune System), and Tmux (Hands).

---

## 🛠️ Discussion Points (Open Questions)
- [x] **The Shared Interface (PocketBase as the Ledger)**: 
  - **Single DB Strategy**: We will use PocketBase (SQLite) for everything. No separate "brain" DB. 
  - **Identity-Based Logic**: Poco and the Human are both `users` in the database. 
  - **Permissions as Safety**:
    - **SOPs**: User-signed, Read-Only for Poco.
    - **Observations**: Write-Access for Poco (Patterns/Scratchpad), Approval-Access for Human.
  - **Vector Acceleration**: We will load `sqlite-vec` into the PocketBase instance to enable semantic search over the shared collections.
- [ ] **Data Hygiene**: How do we prevent Poco from "poisoning" his own memory with malicious observations? (Thresholds, Audits, or separate 'Draft' tables?)
- [x] **Continuity & Heartbeat**: Implemented via the **Reflex Arc**. The system no longer "sleeps" during handoffs; the Proxy nudges the Brain instantly.
- [x] **The "Chain of Command"**: Sub-agents (CAO) report directly to Poco via the Proxy Sensory bridge. Poco remains the OIC (Officer in Charge).
- [ ] **Persistence**: Since OpenCode handles chat history, how do we "inject" our local DB (SOPs/Observations) into that context efficiently?

---
*Last Updated: Feb 2026*
