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

    #[error("embedding result is stale because the memory body changed")]
    StaleEmbedding,

    #[error("embedding must contain exactly 384 finite values with a non-zero norm")]
    InvalidEmbedding,

    #[error("embedding worker is unavailable")]
    EmbedderUnavailable,

    #[error("embedding error: {0}")]
    Embedding(String),

    #[error("failed to register bundled sqlite-vec extension")]
    VectorExtensionRegistration,

    #[error("database error: {0}")]
    Database(#[from] tokio_rusqlite::rusqlite::Error),

    #[error("database worker stopped")]
    DatabaseWorkerStopped,

    #[error("unsupported database schema: {0}")]
    UnsupportedSchema(String),
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
