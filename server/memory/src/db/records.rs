// SPDX-License-Identifier: AGPL-3.0-or-later

use tokio_rusqlite::rusqlite::{OptionalExtension, Row, params};
use uuid::Uuid;

use super::Repository;
use crate::{
    AgentIdentity, MemoryError, Result,
    domain::{ListFilter, MemoryKind, MemoryRecord},
};

const MAX_BODY_BYTES: usize = 256 * 1024;
const MAX_LIST_LIMIT: u32 = 100;

impl Repository {
    /// Creates an unlinked observation attributed to `identity`.
    /// Interpretations must use the atomic linked-creation methods.
    ///
    /// # Errors
    ///
    /// Returns an error for invalid identity/body input or a SQLite failure.
    pub async fn create(
        &self,
        kind: MemoryKind,
        identity: &AgentIdentity,
        body: impl Into<String>,
        now_ms: i64,
    ) -> Result<MemoryRecord> {
        if kind == MemoryKind::Interpretation {
            return Err(MemoryError::InvalidInput(
                "interpretations require at least one linked observation".to_owned(),
            ));
        }
        identity.validate()?;
        let body = validate_body(body.into())?;
        let identity = identity.clone();
        let id = Uuid::now_v7().to_string();
        let returned_id = id.clone();

        self.call(move |connection| {
            let table = table_name(kind);
            connection.execute(
                &format!(
                    "INSERT INTO {table} (\
                        id, account_id, agent_profile_id, agent_name, body, \
                        created_at, updated_at, retrieved_at\
                     ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6, ?6)"
                ),
                params![
                    id,
                    identity.account_id,
                    identity.agent_profile_id,
                    identity.agent_name,
                    body,
                    now_ms,
                ],
            )?;
            get_record(connection, kind, &identity.account_id, &returned_id)?.ok_or_else(|| {
                MemoryError::NotFound {
                    kind,
                    id: returned_id,
                }
            })
        })
        .await
    }

    /// Fetches one canonical record inside an account namespace.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` when the ID does not exist in the supplied account.
    pub async fn get(&self, kind: MemoryKind, account_id: &str, id: &str) -> Result<MemoryRecord> {
        let account_id = account_id.to_owned();
        let id = id.to_owned();
        let missing_id = id.clone();
        self.call(move |connection| {
            get_record(connection, kind, &account_id, &id)?.ok_or(MemoryError::NotFound {
                kind,
                id: missing_id,
            })
        })
        .await
    }

    /// Replaces a record body while retaining its original author attribution.
    ///
    /// # Errors
    ///
    /// Returns an error for an invalid body, missing record, or SQLite failure.
    pub async fn update_body(
        &self,
        kind: MemoryKind,
        account_id: &str,
        id: &str,
        body: impl Into<String>,
        now_ms: i64,
    ) -> Result<MemoryRecord> {
        let body = validate_body(body.into())?;
        let account_id = account_id.to_owned();
        let id = id.to_owned();
        let missing_id = id.clone();
        self.call(move |connection| {
            let table = table_name(kind);
            let changed = connection.execute(
                &format!(
                    "UPDATE {table} SET body = ?1, updated_at = ?2 \
                     WHERE id = ?3 AND account_id = ?4"
                ),
                params![body, now_ms, id, account_id],
            )?;
            if changed == 0 {
                return Err(MemoryError::NotFound {
                    kind,
                    id: missing_id,
                });
            }
            get_record(connection, kind, &account_id, &id)?.ok_or_else(|| MemoryError::NotFound {
                kind,
                id: id.clone(),
            })
        })
        .await
    }

    /// Deletes a canonical record and lets foreign keys cascade its links,
    /// unless deleting an observation would orphan an interpretation.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` when the ID does not exist in the supplied account.
    pub async fn delete(&self, kind: MemoryKind, account_id: &str, id: &str) -> Result<()> {
        let account_id = account_id.to_owned();
        let id = id.to_owned();
        let missing_id = id.clone();
        self.call(move |connection| {
            if kind == MemoryKind::Observation {
                let would_orphan = connection.query_row(
                    "SELECT EXISTS(\
                         SELECT 1 FROM interpretation_observations AS links \
                         WHERE links.observation_id = ?1 \
                           AND (\
                               SELECT count(*) \
                               FROM interpretation_observations AS siblings \
                               WHERE siblings.interpretation_id = links.interpretation_id\
                           ) <= 1\
                     )",
                    [&id],
                    |row| row.get::<_, bool>(0),
                )?;
                if would_orphan {
                    return Err(MemoryError::InvalidInput(
                        "the observation is the final link for an interpretation".to_owned(),
                    ));
                }
            }
            let table = table_name(kind);
            let changed = connection.execute(
                &format!("DELETE FROM {table} WHERE id = ?1 AND account_id = ?2"),
                params![id, account_id],
            )?;
            if changed == 0 {
                Err(MemoryError::NotFound {
                    kind,
                    id: missing_id,
                })
            } else {
                Ok(())
            }
        })
        .await
    }

    /// Lists canonical records in deterministic reverse-creation order.
    ///
    /// # Errors
    ///
    /// Returns an error for an invalid account/limit or a SQLite failure.
    pub async fn list(&self, filter: ListFilter) -> Result<Vec<MemoryRecord>> {
        if filter.account_id.trim().is_empty() {
            return Err(MemoryError::InvalidInput(
                "account_id must not be empty".to_owned(),
            ));
        }
        if filter.limit == 0 || filter.limit > MAX_LIST_LIMIT {
            return Err(MemoryError::InvalidInput(format!(
                "limit must be between 1 and {MAX_LIST_LIMIT}"
            )));
        }
        filter.timestamps.validate()?;

        self.call(move |connection| {
            let table = table_name(filter.kind);
            let sql = format!(
                "SELECT id, account_id, agent_profile_id, agent_name, body, \
                        created_at, updated_at, retrieved_at \
                 FROM {table} \
                 WHERE account_id = ?1 \
                   AND (?2 IS NULL OR agent_profile_id = ?2) \
                   AND (?3 IS NULL OR created_at >= ?3) \
                   AND (?4 IS NULL OR created_at <= ?4) \
                   AND (?5 IS NULL OR updated_at >= ?5) \
                   AND (?6 IS NULL OR updated_at <= ?6) \
                   AND (?7 IS NULL OR retrieved_at >= ?7) \
                   AND (?8 IS NULL OR retrieved_at <= ?8) \
                 ORDER BY created_at DESC, id ASC LIMIT ?9 OFFSET ?10"
            );
            let mut statement = connection.prepare(&sql)?;
            let records = statement
                .query_map(
                    params![
                        filter.account_id,
                        filter.agent_profile_id,
                        filter.timestamps.created_after_ms,
                        filter.timestamps.created_before_ms,
                        filter.timestamps.updated_after_ms,
                        filter.timestamps.updated_before_ms,
                        filter.timestamps.retrieved_after_ms,
                        filter.timestamps.retrieved_before_ms,
                        filter.limit,
                        filter.offset,
                    ],
                    map_record,
                )?
                .collect::<std::result::Result<Vec<_>, _>>()?;
            Ok(records)
        })
        .await
    }

    /// Advances `retrieved_at` for direct search matches in one transaction.
    ///
    /// # Errors
    ///
    /// Returns an error when a result no longer exists in the account or SQLite
    /// cannot commit the transaction.
    pub async fn touch_retrieved(
        &self,
        account_id: &str,
        records: &[(MemoryKind, String)],
        now_ms: i64,
    ) -> Result<()> {
        let account_id = account_id.to_owned();
        let records = records.to_vec();
        self.call(move |connection| {
            let transaction = connection.transaction()?;
            for (kind, id) in records {
                let table = table_name(kind);
                let changed = transaction.execute(
                    &format!(
                        "UPDATE {table} SET retrieved_at = ?1 \
                         WHERE id = ?2 AND account_id = ?3"
                    ),
                    params![now_ms, id, account_id],
                )?;
                if changed == 0 {
                    return Err(MemoryError::NotFound { kind, id });
                }
            }
            transaction.commit()?;
            Ok(())
        })
        .await
    }
}

pub(super) fn validate_body(body: String) -> Result<String> {
    if body.trim().is_empty() {
        return Err(MemoryError::InvalidInput(
            "memory body must not be empty".to_owned(),
        ));
    }
    if body.len() > MAX_BODY_BYTES {
        return Err(MemoryError::InvalidInput(format!(
            "memory body exceeds {MAX_BODY_BYTES} bytes"
        )));
    }
    Ok(body)
}

pub(super) fn table_name(kind: MemoryKind) -> &'static str {
    match kind {
        MemoryKind::Observation => "observations",
        MemoryKind::Interpretation => "interpretations",
    }
}

pub(super) fn get_record(
    connection: &tokio_rusqlite::rusqlite::Connection,
    kind: MemoryKind,
    account_id: &str,
    id: &str,
) -> Result<Option<MemoryRecord>> {
    let table = table_name(kind);
    connection
        .query_row(
            &format!(
                "SELECT id, account_id, agent_profile_id, agent_name, body, \
                        created_at, updated_at, retrieved_at \
                 FROM {table} WHERE id = ?1 AND account_id = ?2"
            ),
            params![id, account_id],
            map_record,
        )
        .optional()
        .map_err(Into::into)
}

fn map_record(row: &Row<'_>) -> tokio_rusqlite::rusqlite::Result<MemoryRecord> {
    Ok(MemoryRecord {
        id: row.get(0)?,
        account_id: row.get(1)?,
        agent_profile_id: row.get(2)?,
        agent_name: row.get(3)?,
        body: row.get(4)?,
        created_at: row.get(5)?,
        updated_at: row.get(6)?,
        retrieved_at: row.get(7)?,
    })
}
