// SPDX-License-Identifier: AGPL-3.0-or-later

use tokio_rusqlite::rusqlite::params;

use crate::{MemoryError, MemoryRecord, Result, db::Repository, domain::MemoryKind};

const MAX_CANDIDATES: u32 = 1_000;

#[derive(Clone, Debug, PartialEq)]
pub struct FtsCandidate {
    pub record: MemoryRecord,
    pub rank: u32,
    pub bm25: f64,
}

impl Repository {
    /// Returns account-scoped FTS candidates ordered by BM25 relevance.
    ///
    /// User text is converted to a literal-token OR query instead of being
    /// interpreted as raw FTS5 query syntax.
    ///
    /// # Errors
    ///
    /// Returns an error for an empty query, an invalid limit, or a SQLite failure.
    pub async fn fts_candidates(
        &self,
        kind: MemoryKind,
        account_id: &str,
        agent_profile_id: Option<&str>,
        query: &str,
        limit: u32,
    ) -> Result<Vec<FtsCandidate>> {
        if account_id.trim().is_empty() {
            return Err(MemoryError::InvalidInput(
                "account_id must not be empty".to_owned(),
            ));
        }
        if limit == 0 || limit > MAX_CANDIDATES {
            return Err(MemoryError::InvalidInput(format!(
                "candidate limit must be between 1 and {MAX_CANDIDATES}"
            )));
        }
        let query = literal_fts_query(query)?;
        let account_id = account_id.to_owned();
        let agent_profile_id = agent_profile_id.map(str::to_owned);

        self.call(move |connection| {
            let (fts_table, content_table) = match kind {
                MemoryKind::Observation => ("observations_fts", "observations"),
                MemoryKind::Interpretation => ("interpretations_fts", "interpretations"),
            };
            let sql = if agent_profile_id.is_some() {
                format!(
                    "SELECT content.id, content.account_id, content.agent_profile_id, \
                            content.agent_name, content.body, content.created_at, \
                            content.updated_at, content.retrieved_at, \
                            bm25({fts_table}) AS relevance \
                     FROM {fts_table} \
                     JOIN {content_table} AS content \
                       ON content.storage_id = {fts_table}.rowid \
                     WHERE {fts_table} MATCH ?1 \
                       AND content.account_id = ?2 \
                       AND content.agent_profile_id = ?3 \
                     ORDER BY relevance ASC, content.updated_at DESC, content.id ASC \
                     LIMIT ?4"
                )
            } else {
                format!(
                    "SELECT content.id, content.account_id, content.agent_profile_id, \
                            content.agent_name, content.body, content.created_at, \
                            content.updated_at, content.retrieved_at, \
                            bm25({fts_table}) AS relevance \
                     FROM {fts_table} \
                     JOIN {content_table} AS content \
                       ON content.storage_id = {fts_table}.rowid \
                     WHERE {fts_table} MATCH ?1 \
                       AND content.account_id = ?2 \
                     ORDER BY relevance ASC, content.updated_at DESC, content.id ASC \
                     LIMIT ?3"
                )
            };
            let mut statement = connection.prepare(&sql)?;
            let rows = if let Some(agent_profile_id) = agent_profile_id {
                statement
                    .query_map(
                        params![query, account_id, agent_profile_id, limit],
                        map_candidate_row,
                    )?
                    .collect::<std::result::Result<Vec<_>, _>>()?
            } else {
                statement
                    .query_map(params![query, account_id, limit], map_candidate_row)?
                    .collect::<std::result::Result<Vec<_>, _>>()?
            };
            rows.into_iter()
                .enumerate()
                .map(|(rank, (record, bm25))| {
                    Ok(FtsCandidate {
                        record,
                        rank: u32::try_from(rank).map_err(|_| {
                            MemoryError::InvalidInput("candidate rank overflow".to_owned())
                        })?,
                        bm25,
                    })
                })
                .collect()
        })
        .await
    }
}

fn map_candidate_row(
    row: &tokio_rusqlite::rusqlite::Row<'_>,
) -> tokio_rusqlite::rusqlite::Result<(MemoryRecord, f64)> {
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
        row.get(8)?,
    ))
}

fn literal_fts_query(query: &str) -> Result<String> {
    let terms = query
        .split_whitespace()
        .map(|term| format!("\"{}\"", term.replace('"', "\"\"")))
        .collect::<Vec<_>>();
    if terms.is_empty() {
        Err(MemoryError::InvalidInput(
            "search query must not be empty".to_owned(),
        ))
    } else {
        Ok(terms.join(" OR "))
    }
}

#[cfg(test)]
mod tests {
    use super::literal_fts_query;

    #[test]
    fn user_query_is_literal_not_fts_syntax() {
        assert_eq!(
            literal_fts_query("alpha OR \"beta\"").unwrap(),
            "\"alpha\" OR \"OR\" OR \"\"\"beta\"\"\""
        );
    }
}
