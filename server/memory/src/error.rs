// SPDX-License-Identifier: AGPL-3.0-or-later

use thiserror::Error;

use crate::domain::MemoryKind;

pub type Result<T> = std::result::Result<T, MemoryError>;

#[derive(Debug, Error)]
pub enum MemoryError {
    #[error("configuration error: {0}")]
    Configuration(String),

    #[error("invalid input: {0}")]
    InvalidInput(String),

    #[error("invalid memory identity context: {0}")]
    InvalidIdentity(String),

    #[error("{kind} {id} was not found")]
    NotFound { kind: MemoryKind, id: String },

    #[error("observation and interpretation must belong to the active account")]
    CrossAccountLink,

    #[error("database error: {0}")]
    Database(#[from] tokio_rusqlite::rusqlite::Error),

    #[error("database worker stopped")]
    DatabaseWorkerStopped,

    #[error("database schema version {found} is newer than supported version {supported}")]
    UnsupportedSchema { found: u32, supported: u32 },
}

impl From<tokio_rusqlite::Error<MemoryError>> for MemoryError {
    fn from(error: tokio_rusqlite::Error<MemoryError>) -> Self {
        match error {
            tokio_rusqlite::Error::Error(inner) => inner,
            tokio_rusqlite::Error::ConnectionClosed | tokio_rusqlite::Error::Close(_) => {
                Self::DatabaseWorkerStopped
            }
            _ => Self::DatabaseWorkerStopped,
        }
    }
}
