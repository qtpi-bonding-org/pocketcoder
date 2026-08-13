// SPDX-License-Identifier: AGPL-3.0-or-later

mod links;
mod native;
mod records;
mod schema;
mod vectors;

pub use vectors::{EMBEDDING_DIMENSION, PendingEmbedding, VectorCandidate};

use std::{path::Path, time::Duration};

use tokio_rusqlite::{Connection, rusqlite};

use crate::{MemoryError, Result};

#[derive(Clone)]
pub struct Repository {
    connection: Connection,
}

impl Repository {
    /// Opens and migrates the SQLite database with the default busy timeout.
    ///
    /// # Errors
    ///
    /// Returns an error when SQLite cannot open, configure, or migrate the file.
    pub async fn open(path: impl AsRef<Path>) -> Result<Self> {
        Self::open_with_busy_timeout(path, Duration::from_secs(5)).await
    }

    /// Opens and migrates the SQLite database with an explicit busy timeout.
    ///
    /// # Errors
    ///
    /// Returns an error when SQLite cannot open, configure, or migrate the file.
    pub async fn open_with_busy_timeout(
        path: impl AsRef<Path>,
        busy_timeout: Duration,
    ) -> Result<Self> {
        native::register_sqlite_vec()?;
        let connection = Connection::open(path)
            .await
            .map_err(MemoryError::Database)?;
        let repository = Self { connection };
        repository.initialize(busy_timeout).await?;
        Ok(repository)
    }

    /// Opens and migrates an isolated in-memory database for tests.
    ///
    /// # Errors
    ///
    /// Returns an error when SQLite cannot initialize or migrate the database.
    pub async fn open_in_memory() -> Result<Self> {
        native::register_sqlite_vec()?;
        let connection = Connection::open_in_memory()
            .await
            .map_err(MemoryError::Database)?;
        let repository = Self { connection };
        repository.initialize(Duration::from_secs(5)).await?;
        Ok(repository)
    }

    async fn initialize(&self, busy_timeout: Duration) -> Result<()> {
        self.call(move |connection| {
            connection.busy_timeout(busy_timeout)?;
            connection.execute_batch(
                "PRAGMA foreign_keys = ON;\n\
                 PRAGMA journal_mode = WAL;\n\
                 PRAGMA synchronous = NORMAL;\n\
                 PRAGMA wal_autocheckpoint = 1000;",
            )?;
            schema::initialize(connection)
        })
        .await
    }

    /// Checkpoints WAL state and stops the repository's database worker.
    ///
    /// # Errors
    ///
    /// Returns an error if the worker has already stopped or SQLite cannot
    /// checkpoint the database.
    pub async fn close(self) -> Result<()> {
        self.connection
            .call(|connection| {
                connection.execute_batch("PRAGMA wal_checkpoint(TRUNCATE);")?;
                Ok::<_, rusqlite::Error>(())
            })
            .await
            .map_err(|_| MemoryError::DatabaseWorkerStopped)?;
        self.connection
            .close()
            .await
            .map_err(|_| MemoryError::DatabaseWorkerStopped)
    }

    pub(crate) async fn call<F, T>(&self, operation: F) -> Result<T>
    where
        F: FnOnce(&mut rusqlite::Connection) -> Result<T> + Send + 'static,
        T: Send + 'static,
    {
        self.connection.call(operation).await.map_err(Into::into)
    }
}
