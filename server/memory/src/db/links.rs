// SPDX-License-Identifier: AGPL-3.0-or-later

use tokio_rusqlite::rusqlite::{OptionalExtension, params};
use uuid::Uuid;

use super::Repository;
use crate::{AgentIdentity, MemoryError, MemoryRecord, Result, domain::MemoryKind};

impl Repository {
    /// Creates an interpretation and all of its initial observation links atomically.
    ///
    /// # Errors
    ///
    /// Returns an error for invalid input, missing/cross-account observations, or
    /// a SQLite failure. No interpretation is retained when link validation fails.
    pub async fn create_interpretation_with_links(
        &self,
        identity: &AgentIdentity,
        body: impl Into<String>,
        observation_ids: &[String],
        now_ms: i64,
    ) -> Result<MemoryRecord> {
        identity.validate()?;
        let body = super::records::validate_body(body.into())?;
        let identity = identity.clone();
        let observation_ids = observation_ids.to_vec();
        let id = Uuid::now_v7().to_string();
        self.call(move |connection| {
            let transaction = connection.transaction()?;
            for observation_id in &observation_ids {
                ensure_account_record(
                    &transaction,
                    MemoryKind::Observation,
                    observation_id,
                    &identity.account_id,
                )?;
            }
            transaction.execute(
                "INSERT INTO interpretations (\
                    id, account_id, agent_profile_id, agent_name, body, \
                    created_at, updated_at, retrieved_at\
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6, ?6)",
                params![
                    id,
                    identity.account_id,
                    identity.agent_profile_id,
                    identity.agent_name,
                    body,
                    now_ms,
                ],
            )?;
            for observation_id in &observation_ids {
                transaction.execute(
                    "INSERT OR IGNORE INTO interpretation_observations (\
                         interpretation_id, observation_id\
                     ) VALUES (?1, ?2)",
                    params![id, observation_id],
                )?;
            }
            let record = super::records::get_record(
                &transaction,
                MemoryKind::Interpretation,
                &identity.account_id,
                &id,
            )?
            .ok_or_else(|| MemoryError::NotFound {
                kind: MemoryKind::Interpretation,
                id: id.clone(),
            })?;
            transaction.commit()?;
            Ok(record)
        })
        .await
    }

    /// Idempotently adds ordinary interpretation-observation links.
    ///
    /// # Errors
    ///
    /// Returns an error when either side is absent, crosses accounts, or SQLite
    /// cannot commit the transaction.
    pub async fn link(
        &self,
        account_id: &str,
        interpretation_id: &str,
        observation_ids: &[String],
    ) -> Result<()> {
        let account_id = account_id.to_owned();
        let interpretation_id = interpretation_id.to_owned();
        let observation_ids = observation_ids.to_vec();
        self.call(move |connection| {
            let transaction = connection.transaction()?;
            ensure_account_record(
                &transaction,
                MemoryKind::Interpretation,
                &interpretation_id,
                &account_id,
            )?;
            for observation_id in &observation_ids {
                ensure_account_record(
                    &transaction,
                    MemoryKind::Observation,
                    observation_id,
                    &account_id,
                )?;
                transaction.execute(
                    "INSERT OR IGNORE INTO interpretation_observations (\
                         interpretation_id, observation_id\
                     ) VALUES (?1, ?2)",
                    params![interpretation_id, observation_id],
                )?;
            }
            transaction.commit()?;
            Ok(())
        })
        .await
    }

    /// Idempotently removes ordinary interpretation-observation links.
    ///
    /// # Errors
    ///
    /// Returns an error when either canonical record is absent, crosses accounts,
    /// or SQLite cannot commit the transaction.
    pub async fn unlink(
        &self,
        account_id: &str,
        interpretation_id: &str,
        observation_ids: &[String],
    ) -> Result<()> {
        let account_id = account_id.to_owned();
        let interpretation_id = interpretation_id.to_owned();
        let observation_ids = observation_ids.to_vec();
        self.call(move |connection| {
            let transaction = connection.transaction()?;
            ensure_account_record(
                &transaction,
                MemoryKind::Interpretation,
                &interpretation_id,
                &account_id,
            )?;
            for observation_id in &observation_ids {
                ensure_account_record(
                    &transaction,
                    MemoryKind::Observation,
                    observation_id,
                    &account_id,
                )?;
                transaction.execute(
                    "DELETE FROM interpretation_observations \
                     WHERE interpretation_id = ?1 AND observation_id = ?2",
                    params![interpretation_id, observation_id],
                )?;
            }
            transaction.commit()?;
            Ok(())
        })
        .await
    }

    /// Lists IDs linked directly to a canonical record in deterministic order.
    ///
    /// # Errors
    ///
    /// Returns an error when the source record is absent or SQLite fails.
    pub async fn linked_ids(
        &self,
        kind: MemoryKind,
        account_id: &str,
        id: &str,
    ) -> Result<Vec<String>> {
        let account_id = account_id.to_owned();
        let id = id.to_owned();
        self.call(move |connection| {
            ensure_account_record(connection, kind, &id, &account_id)?;
            let (sql, parameter) = match kind {
                MemoryKind::Interpretation => (
                    "SELECT observation_id FROM interpretation_observations \
                     WHERE interpretation_id = ?1 ORDER BY observation_id",
                    id,
                ),
                MemoryKind::Observation => (
                    "SELECT interpretation_id FROM interpretation_observations \
                     WHERE observation_id = ?1 ORDER BY interpretation_id",
                    id,
                ),
            };
            let mut statement = connection.prepare(sql)?;
            let ids = statement
                .query_map([parameter], |row| row.get(0))?
                .collect::<std::result::Result<Vec<_>, _>>()?;
            Ok(ids)
        })
        .await
    }
}

fn ensure_account_record(
    connection: &tokio_rusqlite::rusqlite::Connection,
    kind: MemoryKind,
    id: &str,
    account_id: &str,
) -> Result<()> {
    let table = super::records::table_name(kind);
    let owner = connection
        .query_row(
            &format!("SELECT account_id FROM {table} WHERE id = ?1"),
            [id],
            |row| row.get::<_, String>(0),
        )
        .optional()?;
    match owner {
        None => Err(MemoryError::NotFound {
            kind,
            id: id.to_owned(),
        }),
        Some(owner) if owner != account_id => Err(MemoryError::CrossAccountLink),
        Some(_) => Ok(()),
    }
}
