/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Memory Tools. MCP tool implementations for store/recall/search/relate.
use crate::db::{Db, MemoryRecord};
use crate::embed::Embedder;
use rmcp::{
    ErrorData as McpError, ServerHandler,
    handler::server::router::tool::ToolRouter,
    handler::server::wrapper::Parameters,
    model::*,
    schemars, tool, tool_handler, tool_router,
};
use serde::Deserialize;
use std::sync::Arc;
use tracing::error;

// ── Request types (each gets a JsonSchema for MCP introspection) ────────────

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct StoreParams {
    /// The fact or memory text to store.
    pub content: String,
    /// Optional categorization tags.
    #[serde(default)]
    pub tags: Vec<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct RecallParams {
    /// Natural-language query for semantic search.
    pub query: String,
    /// Max results to return (default 5).
    pub limit: Option<usize>,
    /// Decay half-life in days (default 7.0). Older unused memories score lower.
    pub decay_days: Option<f64>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct SearchParams {
    /// Keyword query for full-text BM25 search.
    pub query: String,
    /// Max results to return (default 5).
    pub limit: Option<usize>,
    /// Decay half-life in days (default 7.0).
    pub decay_days: Option<f64>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct DeepRecallParams {
    /// Natural-language query for semantic search (no time decay).
    pub query: String,
    /// Max results to return (default 10).
    pub limit: Option<usize>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct RelateParams {
    /// Source memory ID (e.g. "memory:abc123").
    pub from_id: String,
    /// Target memory ID (e.g. "memory:def456").
    pub to_id: String,
    /// Optional relation label.
    pub label: Option<String>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ForgetParams {
    /// Memory ID to delete (e.g. "memory:abc123").
    pub id: String,
}

// ── Server struct ───────────────────────────────────────────────────────────

#[derive(Clone)]
pub struct PocoMemory {
    db: Db,
    embedder: Arc<Embedder>,
    #[allow(dead_code)]
    tool_router: ToolRouter<Self>,
}

impl PocoMemory {
    pub fn new(db: Db, embedder: Arc<Embedder>) -> Self {
        Self {
            db,
            embedder,
            tool_router: Self::tool_router(),
        }
    }
}

// ── Decay helper ────────────────────────────────────────────────────────────

/// Compute exponential decay: exp(-days_since_retrieval / decay_days)
fn compute_decay(retrieved_at: &str, decay_days: f64) -> f64 {
    let now = chrono::Utc::now();
    let retrieved = chrono::DateTime::parse_from_rfc3339(retrieved_at)
        .or_else(|_| chrono::DateTime::parse_from_str(retrieved_at, "%Y-%m-%dT%H:%M:%S%.fZ"))
        .map(|dt| dt.with_timezone(&chrono::Utc))
        .unwrap_or(now);
    let days = (now - retrieved).num_seconds() as f64 / 86400.0;
    (-days / decay_days).exp()
}

/// Apply decay to candidates, re-sort, take top `limit`, touch retrieved_at.
async fn apply_decay_and_touch(
    db: &Db,
    candidates: Vec<MemoryRecord>,
    score_field: impl Fn(&MemoryRecord) -> f64,
    decay_days: f64,
    limit: usize,
) -> Vec<(MemoryRecord, f64)> {
    let mut scored: Vec<(MemoryRecord, f64)> = candidates
        .into_iter()
        .map(|r| {
            let raw = score_field(&r);
            let decay = compute_decay(&r.retrieved_at, decay_days);
            let final_score = raw * decay;
            (r, final_score)
        })
        .collect();

    scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
    scored.truncate(limit);

    // Touch retrieved_at on returned records
    let ids: Vec<String> = scored.iter().map(|(r, _)| r.id.to_string()).collect();
    if let Err(e) = db.touch_retrieved(&ids).await {
        error!("failed to touch retrieved_at: {e}");
    }

    scored
}

/// Format scored results into MCP text content.
fn format_results(results: &[(MemoryRecord, f64)]) -> String {
    if results.is_empty() {
        return "No memories found.".to_string();
    }
    results
        .iter()
        .map(|(r, score)| {
            format!(
                "[{}] (score: {:.3}, tags: [{}])\n{}",
                r.id,
                score,
                r.tags.join(", "),
                r.content
            )
        })
        .collect::<Vec<_>>()
        .join("\n\n")
}

fn mcp_err(e: impl std::fmt::Display) -> McpError {
    McpError::internal_error(e.to_string(), None)
}

// ── MCP tool implementations ────────────────────────────────────────────────

#[tool_router]
impl PocoMemory {
    #[tool(description = "Store a fact or memory for later recall. Provide content text and optional tags for categorization.")]
    async fn memory_store(
        &self,
        Parameters(params): Parameters<StoreParams>,
    ) -> Result<CallToolResult, McpError> {
        let embedding = self.embedder.embed(&params.content).await.map_err(mcp_err)?;
        let id = self.db.store(params.content, params.tags, embedding).await.map_err(mcp_err)?;
        Ok(CallToolResult::success(vec![Content::text(format!("Memory stored: {id}"))]))
    }

    #[tool(description = "Recall memories by semantic similarity. Recent memories are boosted; old unused ones fade. Use decay_days to control fade speed (default 7).")]
    async fn memory_recall(
        &self,
        Parameters(params): Parameters<RecallParams>,
    ) -> Result<CallToolResult, McpError> {
        let limit = params.limit.unwrap_or(5);
        let decay_days = params.decay_days.unwrap_or(7.0);
        let fetch_limit = limit * 3;

        let embedding = self.embedder.embed(&params.query).await.map_err(mcp_err)?;
        let candidates = self.db.vector_search(embedding, fetch_limit).await.map_err(mcp_err)?;
        let results = apply_decay_and_touch(&self.db, candidates, |r| r.similarity.unwrap_or(0.0), decay_days, limit).await;
        Ok(CallToolResult::success(vec![Content::text(format_results(&results))]))
    }

    #[tool(description = "Search memories by keyword (BM25 full-text search). Recent memories are boosted; old unused ones fade.")]
    async fn memory_search(
        &self,
        Parameters(params): Parameters<SearchParams>,
    ) -> Result<CallToolResult, McpError> {
        let limit = params.limit.unwrap_or(5);
        let decay_days = params.decay_days.unwrap_or(7.0);
        let fetch_limit = limit * 3;

        let candidates = self.db.fts_search(params.query, fetch_limit).await.map_err(mcp_err)?;
        let results = apply_decay_and_touch(&self.db, candidates, |r| r.score.unwrap_or(0.0), decay_days, limit).await;
        Ok(CallToolResult::success(vec![Content::text(format_results(&results))]))
    }

    #[tool(description = "Deep recall: semantic search with NO time decay. Use this to find old/archived memories that normal recall might suppress.")]
    async fn memory_deep_recall(
        &self,
        Parameters(params): Parameters<DeepRecallParams>,
    ) -> Result<CallToolResult, McpError> {
        let limit = params.limit.unwrap_or(10);

        let embedding = self.embedder.embed(&params.query).await.map_err(mcp_err)?;
        let mut candidates = self.db.vector_search(embedding, limit).await.map_err(mcp_err)?;

        // No decay — use raw similarity directly
        let results: Vec<(MemoryRecord, f64)> = candidates
            .drain(..)
            .map(|r| {
                let score = r.similarity.unwrap_or(0.0);
                (r, score)
            })
            .collect();

        // Still touch retrieved_at
        let ids: Vec<String> = results.iter().map(|(r, _)| r.id.to_string()).collect();
        if let Err(e) = self.db.touch_retrieved(&ids).await {
            error!("failed to touch retrieved_at: {e}");
        }

        Ok(CallToolResult::success(vec![Content::text(format_results(&results))]))
    }

    #[tool(description = "Create a named relation between two memories. Use to link related facts.")]
    async fn memory_relate(
        &self,
        Parameters(params): Parameters<RelateParams>,
    ) -> Result<CallToolResult, McpError> {
        let label_display = params.label.as_ref().map(|l| format!(" [{l}]")).unwrap_or_default();
        self.db.relate(&params.from_id, &params.to_id, params.label).await.map_err(mcp_err)?;
        Ok(CallToolResult::success(vec![Content::text(format!(
            "Related {} -> {}{label_display}",
            params.from_id, params.to_id
        ))]))
    }

    #[tool(description = "Permanently delete a memory by its ID.")]
    async fn memory_forget(
        &self,
        Parameters(params): Parameters<ForgetParams>,
    ) -> Result<CallToolResult, McpError> {
        self.db.forget(&params.id).await.map_err(mcp_err)?;
        Ok(CallToolResult::success(vec![Content::text(format!("Forgotten: {}", params.id))]))
    }
}

// ── ServerHandler implementation ────────────────────────────────────────────

#[tool_handler]
impl ServerHandler for PocoMemory {
    fn get_info(&self) -> ServerInfo {
        ServerInfo::new(
            ServerCapabilities::builder()
                .enable_tools()
                .build(),
        )
        .with_server_info(Implementation::new("poco-memory", env!("CARGO_PKG_VERSION")))
        .with_protocol_version(ProtocolVersion::V_2025_03_26)
        .with_instructions(
            "Poco's persistent memory. Use memory_store to save facts, \
             memory_recall for semantic retrieval, memory_search for keyword lookup, \
             memory_deep_recall for archived memories, memory_relate to link facts, \
             and memory_forget to delete.",
        )
    }
}
