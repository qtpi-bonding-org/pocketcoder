# Knowledge Base + Agent Memory Design

Last updated: 2026-03-04

## Decision Summary

Two-layer memory architecture, all backed by a shared SurrealDB instance:

1. **Knowledge Base** (user-curated): OpenNotebook — upload docs, search/chat over them
2. **Agent Memory** (auto-accumulated): Custom Rust/Axum MCP server (`poco-memory`) — agent stores/recalls facts across sessions

## Architecture

```
pocketcoder-knowledge (Docker network)
├── surrealdb              ← shared DB (upstream image, no fork)
│   ├── OpenNotebook tables  → knowledge base
│   ├── poco-memory tables   → agent memory (KV + vector + graph)
│   └── HNSW indexes         → semantic search for both
├── open-notebook          ← knowledge base + UI + MCP (custom image, forked)
├── poco-memory            ← agent memory MCP server (Rust/Axum, ~5MB idle)
└── opencode               ← consumes both via MCP (also on other networks)
```

All behind `--profile knowledge` in Docker Compose (opt-in, like ntfy's `--profile foss`).

## Containers

| Container | Base | Idle RAM | Role |
|---|---|---|---|
| surrealdb | `surrealdb/surrealdb:v2` (upstream) | ~109 MB | Shared database |
| open-notebook | Custom fork of `lfnovo/open-notebook` | ~100-200 MB | Knowledge base + UI + MCP |
| poco-memory | Custom Rust binary (musl static) | ~5 MB | Agent memory MCP server |

## License Landscape

| Component | License | Notes |
|---|---|---|
| PocketCoder | AGPLv3 | Our code |
| OpenNotebook | MIT | Clean |
| SurrealDB | BSL 1.1 | NOT OSI open source. Fine as runtime dependency (same as Docker Engine). Add README note. |
| poco-memory | AGPLv3 | Our code |

README note template:
> PocketCoder's optional knowledge/memory stack uses SurrealDB, which is licensed under BSL 1.1 (not OSI-approved open source). SurrealDB is used as an unmodified runtime dependency. All PocketCoder code remains AGPLv3. If SurrealDB's licensing is a concern, the knowledge and memory features can be disabled via Docker Compose profiles.

## poco-memory MCP Tools

| MCP Tool | What it does | SurrealQL |
|---|---|---|
| `memory_store` | Save a fact with tags | `CREATE memory SET ...` |
| `memory_recall` | Semantic search | `SELECT ... WHERE embedding <\|cosine\|> $vec` |
| `memory_search` | Keyword/FTS search | `SELECT * FROM memory WHERE content @@ $query` |
| `memory_relate` | Link two facts | `RELATE $a->relates_to->$b` |
| `memory_forget` | Delete a memory | `DELETE $id` |

Stack: Rust + Axum + surrealdb (Rust client SDK) + fastembed-rs (local embeddings, no API key)

## Network Design

- New network: `pocketcoder-knowledge`
- SurrealDB: only on `pocketcoder-knowledge` (fully isolated)
- OpenNotebook: only on `pocketcoder-knowledge`
- poco-memory: only on `pocketcoder-knowledge`
- OpenCode: joins `pocketcoder-knowledge` (in addition to existing networks)
- OpenCode connects to both MCP servers directly (not through MCP gateway)

## OpenNotebook Integration Notes

- Option A chosen: keep UI, make optional (accessible via PB proxy or direct port)
- OpenNotebook has REST API at `/docs` (Swagger) and native MCP server
- Supports Ollama for embeddings (sovereignty-aligned)
- Frontend is Next.js baked into same container — minimal overhead
- SurrealDB connection: `ws://surrealdb:8000/rpc`

## Why NOT Other Options

| Rejected | Reason |
|---|---|
| Qdrant | Extra container when SurrealDB already has HNSW vector search |
| Mem0 | 3 containers, hidden LLM cost for extraction, overkill |
| Remembrances-MCP | Indie project, low bus factor, simpler to build our own |
| Chroma | No hybrid search, heavier than SurrealDB |
| Anthropic server-memory | No semantic search |

## Implementation Order

1. **Phase 1: OpenNotebook** [IN PROGRESS] — Upstream image + MCP wrapper added to Compose with `--profile knowledge`, SurrealDB wired, BATS tests written
2. **Phase 2: poco-memory** — Rust MCP server, SurrealDB schema, fastembed integration, 5 MCP tools, add to Compose
3. **Phase 3: Interface wiring** — Auto-index chat summaries into poco-memory after conversations

## References

- OpenNotebook: https://github.com/lfnovo/open-notebook
- SurrealDB vector docs: https://surrealdb.com/docs/surrealdb/models/vector
- SurrealMCP: https://github.com/surrealdb/surrealmcp
- SurrealDB 3.0 agent memory: https://surrealdb.com/blog/introducing-surrealdb-3-0--the-future-of-ai-agent-memory
- fastembed-rs: https://github.com/Anush008/fastembed-rs
- OpenClaw comparison: docs/openclaw-comparison.md (Section 4: Memory)
