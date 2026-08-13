// SPDX-License-Identifier: AGPL-3.0-or-later

use tokio_rusqlite::rusqlite::{self, Connection, OptionalExtension};

use crate::{MemoryError, Result};

const SCHEMA_ID: &str = "pocket-memory-v1";
const SCHEMA: &str = include_str!("../../schema.sql");

pub(super) fn initialize(connection: &mut Connection) -> Result<()> {
    let marker_exists = connection.query_row(
        "SELECT EXISTS(SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = 'memory_schema')",
        [],
        |row| row.get::<_, bool>(0),
    )?;
    if !marker_exists {
        let object_count = connection.query_row(
            "SELECT count(*) FROM sqlite_schema WHERE name NOT LIKE 'sqlite_%'",
            [],
            |row| row.get::<_, u32>(0),
        )?;
        if object_count != 0 {
            return Err(MemoryError::UnsupportedSchema(
                "database is non-empty and has no Pocket Memory schema marker".to_owned(),
            ));
        }
        let transaction = connection.transaction()?;
        transaction.execute_batch(SCHEMA)?;
        transaction.commit()?;
    }

    let found = connection
        .query_row("SELECT schema_id FROM memory_schema LIMIT 1", [], |row| {
            row.get::<_, String>(0)
        })
        .optional()?;
    if found.as_deref() != Some(SCHEMA_ID) {
        return Err(MemoryError::UnsupportedSchema(
            found.unwrap_or_else(|| "memory_schema is empty".to_owned()),
        ));
    }
    ensure_foreign_keys(connection)?;
    Ok(())
}

fn ensure_foreign_keys(connection: &Connection) -> rusqlite::Result<()> {
    let enabled = connection.query_row("PRAGMA foreign_keys", [], |row| row.get::<_, bool>(0))?;
    if enabled {
        Ok(())
    } else {
        Err(rusqlite::Error::InvalidQuery)
    }
}
