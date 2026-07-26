# Poco Memory: Hybrid Functional Plumbing

## 🎯 Objective
To create a memory system that mimics biological forgetting (Ebbinghaus Forgetting Curve) while maintaining the digital advantage of perfect "Deep Recall." This system prioritizes context signal-to-noise ratio by exponentially deranking older, unused information while keeping it "in the ghosts" for manual retrieval.

---

## 🏗️ Functional Tiers

### 1. Key-Value (KV) Store: "The Hard Facts"
*   **Function:** Immediate, deterministic lookup of system-critical data.
*   **Behavior:** Binary persistence. Either it is true and current, or it is stale and gone.
*   **Decay:** Hard TTL. When the timer hits zero, the record is **deleted**. Stale facts (like an old port number or an old session ID) are considered dangerous noise.

### 2. Hybrid Store: "The Semantic Safety Net"
*   **Function:** Finding information that "feels like" what we are looking for.
*   **Mechanism:** Vector Search (Embeddings) + Full-Text Search (Keywords).
*   **Behavior:** Exponential deranking.
*   **Decay:** Every successful retrieval resets the "Activity Score." Unused memories sink into the "Ghost Tier."

### 3. Graph RAG: "The Relational Logic"
*   **Function:** Understanding the *Why* and the *How* through connections.
*   **Mechanism:** Triplet store (Subject → Predicate → Object).
*   **Behavior:** Relationship-first decay. Connections (Edges) between nodes can weaken or break while the nodes (Entities) remain.

---

## 📉 The Decay & Deranking Algorithm

Each memory entry in the **Hybrid** and **Graph** tiers contains a `weight` coefficient (0.0 to 1.0) and a `last_accessed` timestamp.

### 1. Exponential Decay (The Default State)
Poco's "Focus" is maintained by keeping the context window free of "Ghostly" clutter.
*   **Active Memory:** `weight >= 0.7`. Injected into prompt as "Relevant Context."
*   **Faded Memory:** `0.7 > weight >= 0.3`. Only returned if no Active memories match the query.
*   **Ghost Memory:** `weight < 0.3`. Hidden from standard retrieval tools.

### 2. The "Deep Recall" Trigger
When the user or Poco activates the **"Temporal Flux"** flag (e.g., "Think back to the beginning of the project"):
*   The exponential derank is ignored/multiplied by `1/weight`.
*   All Ghost memories are resurrected to `weight = 1.0` for the duration of that turn.
*   **Crucial:** Every resurrected memory is returned to Poco with its ORIGINAL `created_at` timestamp.

---

## 🕰️ Chronological Resolution (Timestamp Context)
When Poco receives a mix of "Active" and "Resurrected" memories, he uses the timestamps to handle contradictions:
*   *Memory A (2023):* "Decided to use SQLite for memory."
*   *Memory B (2024):* "Decided to use PocketBase for memory."
*   **Result:** Poco sees that "B" is newer and interprets "A" as legacy/historical context rather than a current instruction.

---

## 🗄️ Proposed Backend Plumbing (PocketBase)

### Collection: `pc_memories`
| Field | Type | Purpose |
| :--- | :--- | :--- |
| `type` | Select | `kv`, `semantic`, `graph_node`, `graph_edge` |
| `key` | Text | Unique identifier for KV or Node name |
| `value` | JSON | The actual content/fact/metadata |
| `weight` | Number | 0.0 to 1.0 (Calculated dynamically or periodically updated) |
| `ttl` | Number | Milliseconds until Hard Delete (Mostly for KV) |
| `last_accessed` | Date | Used to reset the decay curve |
| `metadata` | JSON | Vector embeddings, parent relations, or lineage |
| `created` | Date | System timestamp for Chronological Resolution |

---

## 🔄 The Lifecycle Loop
1.  **Extraction:** Poco learns a fact and pushes it to the plumbing via the `save_memory` tool.
2.  **Usage:** Poco calls `query_memory`. The backend returns matches, but filters out `weight < 0.3`.
3.  **Reinforcement:** Every memory used in a successful turn gets `last_accessed` updated (weight resets to 1.0).
4.  **Deranking:** A background job (or periodic trigger) decays the `weight` of all untouched memories by `X%` daily.
5.  **Pruning:** KV memories with expired TTLs are purged.
