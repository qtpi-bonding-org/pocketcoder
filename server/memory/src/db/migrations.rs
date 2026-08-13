// SPDX-License-Identifier: AGPL-3.0-or-later

use tokio_rusqlite::rusqlite::{self, Connection};

use crate::{MemoryError, Result};

const CURRENT_VERSION: u32 = 1;
const INITIAL_SCHEMA: &str = include_str!("../../migrations/0001_initial.sql");

pub(super) fn apply(connection: &mut Connection) -> Result<()> {
    let found = connection.query_row("PRAGMA user_version", [], |row| row.get::<_, u32>(0))?;
    if found > CURRENT_VERSION {
        return Err(MemoryError::UnsupportedSchema {
            found,
            supported: CURRENT_VERSION,
        });
    }

    if found == 0 {
        let transaction = connection.transaction()?;
        transaction.execute_batch(INITIAL_SCHEMA)?;
        transaction.pragma_update(None, "user_version", CURRENT_VERSION)?;
        transaction.commit()?;
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
