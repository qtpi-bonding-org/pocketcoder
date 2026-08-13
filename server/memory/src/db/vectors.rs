// SPDX-License-Identifier: AGPL-3.0-or-later

use sha2::{Digest, Sha256};
use tokio_rusqlite::rusqlite::{OptionalExtension, params};

use super::{Repository, records::table_name};
use crate::{
    MemoryError, MemoryRecord, Result,
    domain::{MemoryKind, TimestampFilter},
};

pub const EMBEDDING_DIMENSION: usize = 384;
const MAX_VECTOR_CANDIDATES: u32 = 1_000;

#[derive(Clone, Debug, PartialEq)]
pub struct VectorCandidate {
    pub record: MemoryRecord,
    pub rank: u32,
    pub distance: f64,
    pub similarity: f64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PendingEmbedding {
    pub kind: MemoryKind,
    pub id: String,
    pub account_id: String,
    pub body: String,
}

impl Repository {
    /// Stores a derived vector only if the canonical body still matches.
    ///
    /// # Errors
    ///
    /// Returns an error for invalid vectors, missing/cross-account records,
    /// concurrent body changes, or a SQLite failure.
    #[allow(clippy::too_many_arguments)]
    pub async fn store_embedding(
        &self,
        kind: MemoryKind,
        account_id: &str,
        id: &str,
        source_body: &str,
        embedding: &[f32],
        embedding_version: &str,
        embedded_at: i64,
    ) -> Result<()> {
        validate_embedding(embedding)?;
        if embedding_version.trim().is_empty() {
            return Err(MemoryError::InvalidInput(
                "embedding_version must not be empty".to_owned(),
            ));
        }
        let account_id = account_id.to_owned();
        let id = id.to_owned();
        let source_body = source_body.to_owned();
        let embedding_blob = embedding_blob(embedding);
        let source_hash = Sha256::digest(source_body.as_bytes()).to_vec();
        let embedding_version = embedding_version.to_owned();

        self.call(move |connection| {
            let content_table = table_name(kind);
            let (vector_table, state_table) = derived_tables(kind);
            let canonical = connection
                .query_row(
                    &format!(
                        "SELECT storage_id, body FROM {content_table} \
                         WHERE id = ?1 AND account_id = ?2"
                    ),
                    params![id, account_id],
                    |row| Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?)),
                )
                .optional()?;
            let Some((storage_id, current_body)) = canonical else {
                return Err(MemoryError::NotFound { kind, id });
            };
            if current_body != source_body {
                return Err(MemoryError::StaleEmbedding);
            }

            let transaction = connection.transaction()?;
            transaction.execute(
                &format!("DELETE FROM {vector_table} WHERE storage_id = ?1"),
                [storage_id],
            )?;
            transaction.execute(
                &format!(
                    "INSERT INTO {vector_table} (storage_id, embedding, account_id) \
                     VALUES (?1, ?2, ?3)"
                ),
                params![storage_id, embedding_blob, account_id],
            )?;
            transaction.execute(
                &format!(
                    "INSERT INTO {state_table} (\
                         storage_id, source_hash, embedding_version, embedded_at\
                     ) VALUES (?1, ?2, ?3, ?4) \
                     ON CONFLICT(storage_id) DO UPDATE SET \
                         source_hash = excluded.source_hash, \
                         embedding_version = excluded.embedding_version, \
                         embedded_at = excluded.embedded_at"
                ),
                params![storage_id, source_hash, embedding_version, embedded_at],
            )?;
            transaction.commit()?;
            Ok(())
        })
        .await
    }

    /// Returns account-scoped cosine-nearest candidates.
    ///
    /// # Errors
    ///
    /// Returns an error for an invalid query vector/limit or a SQLite failure.
    pub async fn vector_candidates(
        &self,
        kind: MemoryKind,
        account_id: &str,
        agent_profile_id: Option<&str>,
        timestamps: TimestampFilter,
        embedding: &[f32],
        limit: u32,
    ) -> Result<Vec<VectorCandidate>> {
        validate_embedding(embedding)?;
        if limit == 0 || limit > MAX_VECTOR_CANDIDATES {
            return Err(MemoryError::InvalidInput(format!(
                "vector candidate limit must be between 1 and {MAX_VECTOR_CANDIDATES}"
            )));
        }
        timestamps.validate()?;
        let account_id = account_id.to_owned();
        let agent_profile_id = agent_profile_id.map(str::to_owned);
        let nearest_limit = if agent_profile_id.is_some() || !timestamps.is_empty() {
            MAX_VECTOR_CANDIDATES
        } else {
            limit
        };
        let embedding_blob = embedding_blob(embedding);
        self.call(move |connection| {
            let content_table = table_name(kind);
            let (vector_table, _) = derived_tables(kind);
            let sql = format!(
                "WITH nearest AS (\
                     SELECT storage_id, distance FROM {vector_table} \
                     WHERE embedding MATCH ?1 AND k = ?2 AND account_id = ?3\
                 ) \
                 SELECT content.id, content.account_id, content.agent_profile_id, \
                        content.agent_name, content.body, content.created_at, \
                        content.updated_at, content.retrieved_at, nearest.distance \
                 FROM nearest \
                 JOIN {content_table} AS content USING (storage_id) \
                 WHERE (?4 IS NULL OR content.agent_profile_id = ?4) \
                   AND (?5 IS NULL OR content.created_at >= ?5) \
                   AND (?6 IS NULL OR content.created_at <= ?6) \
                   AND (?7 IS NULL OR content.updated_at >= ?7) \
                   AND (?8 IS NULL OR content.updated_at <= ?8) \
                   AND (?9 IS NULL OR content.retrieved_at >= ?9) \
                   AND (?10 IS NULL OR content.retrieved_at <= ?10) \
                 ORDER BY nearest.distance ASC, content.updated_at DESC, content.id ASC \
                 LIMIT ?11"
            );
            let mut statement = connection.prepare(&sql)?;
            let map_row = |row: &tokio_rusqlite::rusqlite::Row<'_>| {
                Ok((
                    MemoryRecord {
                        id: row.get(0)?,
                        account_id: row.get(1)?,
                        agent_profile_id: row.get(2)?,
                        agent_name: row.get(3)?,
                        body: row.get(4)?,
                        created_at: row.get(5)?,
                        updated_at: row.get(6)?,
                        retrieved_at: row.get(7)?,
                    },
                    row.get::<_, f64>(8)?,
                ))
            };
            let rows = statement
                .query_map(
                    params![
                        embedding_blob,
                        nearest_limit,
                        account_id,
                        agent_profile_id,
                        timestamps.created_after_ms,
                        timestamps.created_before_ms,
                        timestamps.updated_after_ms,
                        timestamps.updated_before_ms,
                        timestamps.retrieved_after_ms,
                        timestamps.retrieved_before_ms,
                        limit,
                    ],
                    map_row,
                )?
                .collect::<std::result::Result<Vec<_>, _>>()?;
            rows.into_iter()
                .enumerate()
                .map(|(rank, (record, distance))| {
                    Ok(VectorCandidate {
                        record,
                        rank: u32::try_from(rank).map_err(|_| {
                            MemoryError::InvalidInput("vector rank overflow".to_owned())
                        })?,
                        distance,
                        similarity: 1.0 - distance,
                    })
                })
                .collect()
        })
        .await
    }

    /// Lists canonical rows whose current embedding is absent or from another version.
    ///
    /// # Errors
    ///
    /// Returns an error for an invalid limit or a SQLite failure.
    pub async fn pending_embeddings(
        &self,
        kind: MemoryKind,
        embedding_version: &str,
        limit: u32,
    ) -> Result<Vec<PendingEmbedding>> {
        if limit == 0 || limit > MAX_VECTOR_CANDIDATES {
            return Err(MemoryError::InvalidInput(format!(
                "pending embedding limit must be between 1 and {MAX_VECTOR_CANDIDATES}"
            )));
        }
        let embedding_version = embedding_version.to_owned();
        self.call(move |connection| {
            let content_table = table_name(kind);
            let (_, state_table) = derived_tables(kind);
            let mut statement = connection.prepare(&format!(
                "SELECT content.id, content.account_id, content.body \
                 FROM {content_table} AS content \
                 LEFT JOIN {state_table} AS state USING (storage_id) \
                 WHERE state.storage_id IS NULL OR state.embedding_version != ?1 \
                 ORDER BY content.storage_id ASC LIMIT ?2"
            ))?;
            let rows = statement
                .query_map(params![embedding_version, limit], |row| {
                    Ok(PendingEmbedding {
                        kind,
                        id: row.get(0)?,
                        account_id: row.get(1)?,
                        body: row.get(2)?,
                    })
                })?
                .collect::<std::result::Result<Vec<_>, _>>()?;
            Ok(rows)
        })
        .await
    }
}

fn derived_tables(kind: MemoryKind) -> (&'static str, &'static str) {
    match kind {
        MemoryKind::Observation => ("observation_vectors", "observation_embedding_state"),
        MemoryKind::Interpretation => ("interpretation_vectors", "interpretation_embedding_state"),
    }
}

fn validate_embedding(embedding: &[f32]) -> Result<()> {
    let norm_squared = embedding.iter().map(|value| value * value).sum::<f32>();
    if embedding.len() != EMBEDDING_DIMENSION
        || embedding.iter().any(|value| !value.is_finite())
        || !norm_squared.is_finite()
        || norm_squared < 1.0e-12
    {
        Err(MemoryError::InvalidEmbedding)
    } else {
        Ok(())
    }
}

fn embedding_blob(embedding: &[f32]) -> Vec<u8> {
    embedding
        .iter()
        .flat_map(|value| value.to_le_bytes())
        .collect()
}
