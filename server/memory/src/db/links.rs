// SPDX-License-Identifier: AGPL-3.0-or-later

use std::collections::BTreeSet;

use tokio_rusqlite::rusqlite::{OptionalExtension, params};
use uuid::Uuid;

use super::Repository;
use crate::{AgentIdentity, MemoryError, MemoryRecord, Result, domain::MemoryKind};

impl Repository {
    /// Creates an interpretation and one or more equal observation links atomically.
    ///
    /// # Errors
    ///
    /// Returns an error for empty links, invalid input, missing/cross-account
    /// observations, or a SQLite failure. No interpretation is retained when
    /// validation fails.
    pub async fn create_interpretation_with_links(
        &self,
        identity: &AgentIdentity,
        body: impl Into<String>,
        observation_ids: &[String],
        now_ms: i64,
    ) -> Result<MemoryRecord> {
        identity.validate()?;
        let body = super::records::validate_body(body.into())?;
        let observation_ids = unique_observation_ids(observation_ids)?;
        let identity = identity.clone();
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
            for observation_id in &observation_ids {
                transaction.execute(
                    "INSERT INTO interpretation_observations (\
                         interpretation_id, observation_id\
                     ) VALUES (?1, ?2)",
                    params![&id, observation_id],
                )?;
            }
            transaction.execute(
                "INSERT INTO interpretations (\
                    id, account_id, agent_profile_id, agent_name, body, \
                    created_at, updated_at, retrieved_at\
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6, ?6)",
                params![
                    &id,
                    &identity.account_id,
                    &identity.agent_profile_id,
                    &identity.agent_name,
                    &body,
                    now_ms,
                ],
            )?;
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

    /// Creates a new observation and an interpretation linked to it, plus any
    /// existing observations, in one transaction.
    ///
    /// # Errors
    ///
    /// Returns an error for invalid input, missing/cross-account existing
    /// observations, or a SQLite failure. Neither new record is retained when
    /// validation fails.
    pub async fn create_observation_with_interpretation(
        &self,
        identity: &AgentIdentity,
        observation_body: impl Into<String>,
        interpretation_body: impl Into<String>,
        additional_observation_ids: &[String],
        now_ms: i64,
    ) -> Result<(MemoryRecord, MemoryRecord)> {
        identity.validate()?;
        let observation_body = super::records::validate_body(observation_body.into())?;
        let interpretation_body = super::records::validate_body(interpretation_body.into())?;
        let additional_observation_ids = additional_observation_ids
            .iter()
            .cloned()
            .collect::<BTreeSet<_>>();
        let identity = identity.clone();
        let observation_id = Uuid::now_v7().to_string();
        let interpretation_id = Uuid::now_v7().to_string();

        self.call(move |connection| {
            let transaction = connection.transaction()?;
            for additional_id in &additional_observation_ids {
                ensure_account_record(
                    &transaction,
                    MemoryKind::Observation,
                    additional_id,
                    &identity.account_id,
                )?;
            }
            transaction.execute(
                "INSERT INTO observations (\
                    id, account_id, agent_profile_id, agent_name, body, \
                    created_at, updated_at, retrieved_at\
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6, ?6)",
                params![
                    &observation_id,
                    &identity.account_id,
                    &identity.agent_profile_id,
                    &identity.agent_name,
                    &observation_body,
                    now_ms,
                ],
            )?;
            transaction.execute(
                "INSERT INTO interpretation_observations (\
                     interpretation_id, observation_id\
                 ) VALUES (?1, ?2)",
                params![&interpretation_id, &observation_id],
            )?;
            for additional_id in &additional_observation_ids {
                transaction.execute(
                    "INSERT INTO interpretation_observations (\
                         interpretation_id, observation_id\
                     ) VALUES (?1, ?2)",
                    params![&interpretation_id, additional_id],
                )?;
            }
            transaction.execute(
                "INSERT INTO interpretations (\
                    id, account_id, agent_profile_id, agent_name, body, \
                    created_at, updated_at, retrieved_at\
                 ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6, ?6)",
                params![
                    &interpretation_id,
                    &identity.account_id,
                    &identity.agent_profile_id,
                    &identity.agent_name,
                    &interpretation_body,
                    now_ms,
                ],
            )?;
            let observation = super::records::get_record(
                &transaction,
                MemoryKind::Observation,
                &identity.account_id,
                &observation_id,
            )?
            .ok_or_else(|| MemoryError::NotFound {
                kind: MemoryKind::Observation,
                id: observation_id.clone(),
            })?;
            let interpretation = super::records::get_record(
                &transaction,
                MemoryKind::Interpretation,
                &identity.account_id,
                &interpretation_id,
            )?
            .ok_or_else(|| MemoryError::NotFound {
                kind: MemoryKind::Interpretation,
                id: interpretation_id.clone(),
            })?;
            transaction.commit()?;
            Ok((observation, interpretation))
        })
        .await
    }

    /// Idempotently adds equal interpretation-observation links.
    ///
    /// # Errors
    ///
    /// Returns an error when either side is absent, crosses accounts, or the
    /// transaction cannot be committed.
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

    /// Idempotently removes links without allowing an interpretation to become
    /// disconnected from every observation.
    ///
    /// # Errors
    ///
    /// Returns an error when either side is absent, crosses accounts, removing
    /// the links would orphan the interpretation, or the transaction fails.
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
                let linked = transaction.query_row(
                    "SELECT EXISTS(\
                         SELECT 1 FROM interpretation_observations \
                         WHERE interpretation_id = ?1 AND observation_id = ?2\
                     )",
                    params![&interpretation_id, observation_id],
                    |row| row.get::<_, bool>(0),
                )?;
                if !linked {
                    continue;
                }
                let link_count = transaction.query_row(
                    "SELECT count(*) FROM interpretation_observations \
                     WHERE interpretation_id = ?1",
                    [&interpretation_id],
                    |row| row.get::<_, i64>(0),
                )?;
                if link_count <= 1 {
                    return Err(MemoryError::InvalidInput(
                        "an interpretation must remain linked to at least one observation"
                            .to_owned(),
                    ));
                }
                transaction.execute(
                    "DELETE FROM interpretation_observations \
                     WHERE interpretation_id = ?1 AND observation_id = ?2",
                    params![&interpretation_id, observation_id],
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
    /// Returns an error when the source record is absent, crosses accounts, or
    /// SQLite cannot read its links.
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

fn unique_observation_ids(observation_ids: &[String]) -> Result<BTreeSet<String>> {
    let ids = observation_ids.iter().cloned().collect::<BTreeSet<_>>();
    if ids.is_empty() {
        return Err(MemoryError::InvalidInput(
            "an interpretation requires at least one observation".to_owned(),
        ));
    }
    Ok(ids)
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
