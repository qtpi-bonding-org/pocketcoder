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

// @pocketcoder-core: Memory Database. SurrealDB interface for memory persistence and vector search.
use serde::{Deserialize, Serialize};
use surrealdb::engine::remote::ws::Ws;
use surrealdb::opt::auth::Root;
use surrealdb::sql::Thing;
use surrealdb::Surreal;
use tracing::info;

/// SurrealDB connection wrapper.
#[derive(Clone)]
pub struct Db {
    client: Surreal<surrealdb::engine::remote::ws::Client>,
}

/// A memory record as returned by queries.
#[derive(Debug, Serialize, Deserialize)]
pub struct MemoryRecord {
    pub id: Thing,
    pub content: String,
    #[serde(default)]
    pub tags: Vec<String>,
    pub created_at: String,
    pub retrieved_at: String,
    pub access_count: i64,
    pub decay_rate_days: f64,
    /// Present on vector search results.
    #[serde(default)]
    pub similarity: Option<f64>,
    /// Present on FTS results.
    #[serde(default)]
    pub score: Option<f64>,
}

/// Minimal record for CREATE return.
#[derive(Debug, Deserialize)]
pub struct CreatedRecord {
    pub id: Thing,
}

/// Single source of truth for the touch_retrieved SQL — used by both the
/// production method and the test that asserts its semantics.
fn touch_retrieved_query(id: &str) -> String {
    format!("UPDATE {id} SET retrieved_at = time::now(), access_count += 1")
}

impl Db {
    /// Connect to SurrealDB, sign in, select namespace/database, run schema.
    pub async fn new(url: &str, user: &str, pass: &str, ns: &str, database: &str) -> anyhow::Result<Self> {
        info!(url, "connecting to SurrealDB");
        let client = Surreal::new::<Ws>(url).await?;

        client
            .signin(Root {
                username: user,
                password: pass,
            })
            .await?;

        client.use_ns(ns).use_db(database).await?;

        // Run schema (idempotent DEFINE statements)
        let schema = include_str!("schema.sql");
        client.query(schema).await?.check()?;
        info!("schema initialized");

        Ok(Self { client })
    }

    /// Store a new memory, returning its record ID.
    pub async fn store(
        &self,
        content: String,
        tags: Vec<String>,
        embedding: Vec<f32>,
        decay_rate_days: f64,
    ) -> anyhow::Result<String> {
        let mut result = self
            .client
            .query(
                "CREATE memory SET content = $content, tags = $tags, embedding = $embedding, \
                 decay_rate_days = $decay_rate_days, \
                 created_at = time::now(), retrieved_at = time::now()",
            )
            .bind(("content", content))
            .bind(("tags", tags))
            .bind(("embedding", embedding))
            .bind(("decay_rate_days", decay_rate_days))
            .await?;

        let created: Option<CreatedRecord> = result.take(0)?;
        let id = created
            .ok_or_else(|| anyhow::anyhow!("CREATE returned no record"))?
            .id;
        Ok(id.to_string())
    }

    /// Semantic vector search — brute-force cosine similarity (reliable at any dataset size).
    pub async fn vector_search(&self, embedding: Vec<f32>, fetch_limit: usize) -> anyhow::Result<Vec<MemoryRecord>> {
        let query = format!(
            "SELECT *, vector::similarity::cosine(embedding, $vec) AS similarity \
             FROM memory ORDER BY similarity DESC LIMIT {fetch_limit}"
        );
        let mut result = self.client.query(&query).bind(("vec", embedding)).await?;
        let records: Vec<MemoryRecord> = result.take(0)?;
        Ok(records)
    }

    /// Full-text BM25 search — returns candidates for decay reranking.
    pub async fn fts_search(&self, query_text: String, fetch_limit: usize) -> anyhow::Result<Vec<MemoryRecord>> {
        let query = format!(
            "SELECT *, search::score(1) AS score FROM memory \
             WHERE content @1@ $query ORDER BY score DESC LIMIT {fetch_limit}"
        );
        let mut result = self.client.query(&query).bind(("query", query_text)).await?;
        let records: Vec<MemoryRecord> = result.take(0)?;
        Ok(records)
    }

    /// Batch-update retrieved_at + access_count on returned memories.
    pub async fn touch_retrieved(&self, ids: &[String]) -> anyhow::Result<()> {
        for id in ids {
            self.client.query(&touch_retrieved_query(id)).await?;
        }
        Ok(())
    }

    /// Create a relation between two memories.
    pub async fn relate(&self, from_id: &str, to_id: &str, label: Option<String>) -> anyhow::Result<()> {
        // Record IDs must be interpolated directly — RELATE doesn't support bind params for endpoints
        let query = match label {
            Some(ref l) => format!("RELATE {from_id}->relates_to->{to_id} SET label = $label"),
            None => format!("RELATE {from_id}->relates_to->{to_id}"),
        };
        let mut q = self.client.query(&query);
        if let Some(l) = label {
            q = q.bind(("label", l));
        }
        q.await?.check()?;
        Ok(())
    }

    /// Delete a memory by ID.
    pub async fn forget(&self, id: &str) -> anyhow::Result<()> {
        // Record ID interpolated directly — DELETE <id> is the SurrealDB pattern
        let query = format!("DELETE {id}");
        self.client.query(&query).await?.check()?;
        Ok(())
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use surrealdb::engine::local::Mem;

    /// Spin up an in-process SurrealDB and apply schema.sql.
    async fn setup_mem_client() -> Surreal<surrealdb::engine::local::Db> {
        let client = Surreal::new::<Mem>(()).await.expect("mem connect");
        client.use_ns("test").use_db("test").await.expect("ns/db");
        let schema = include_str!("schema.sql");
        client.query(schema).await.expect("schema query").check().expect("schema ok");
        client
    }

    #[derive(Deserialize)]
    struct AccessCountRow {
        access_count: i64,
    }

    #[derive(Deserialize)]
    struct DefaultsRow {
        access_count: i64,
        decay_rate_days: f64,
    }

    #[tokio::test]
    async fn schema_defaults_apply_on_create() {
        let client = setup_mem_client().await;

        // Create a memory without setting access_count or decay_rate_days —
        // schema DEFAULT clauses should fill them.
        client
            .query("CREATE memory:row1 SET content = 'hi', tags = [], embedding = $emb")
            .bind(("emb", vec![0.0_f32; 384]))
            .await
            .expect("create");

        let mut r = client
            .query("SELECT access_count, decay_rate_days FROM memory:row1")
            .await
            .expect("select");
        let rows: Vec<DefaultsRow> = r.take(0).expect("take");
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].access_count, 0, "schema default access_count must be 0");
        assert!(
            (rows[0].decay_rate_days - 7.0).abs() < f64::EPSILON,
            "schema default decay_rate_days must be 7.0, got {}",
            rows[0].decay_rate_days,
        );
    }

    #[tokio::test]
    async fn touch_retrieved_increments_access_count() {
        let client = setup_mem_client().await;

        client
            .query("CREATE memory:row2 SET content = 'hi', tags = [], embedding = $emb")
            .bind(("emb", vec![0.0_f32; 384]))
            .await
            .expect("create");

        // Use the production-shared SQL helper so a refactor of the SQL is
        // caught here too.
        client
            .query(touch_retrieved_query("memory:row2"))
            .await
            .expect("touch 1");

        let mut r = client
            .query("SELECT access_count FROM memory:row2")
            .await
            .expect("select 1");
        let rows: Vec<AccessCountRow> = r.take(0).expect("take 1");
        assert_eq!(rows[0].access_count, 1, "first touch should set access_count = 1");

        // Two more touches → 3
        client
            .query(touch_retrieved_query("memory:row2"))
            .await
            .expect("touch 2");
        client
            .query(touch_retrieved_query("memory:row2"))
            .await
            .expect("touch 3");

        let mut r = client
            .query("SELECT access_count FROM memory:row2")
            .await
            .expect("select 2");
        let rows: Vec<AccessCountRow> = r.take(0).expect("take 2");
        assert_eq!(rows[0].access_count, 3, "three touches should set access_count = 3");
    }
}
