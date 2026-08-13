// SPDX-License-Identifier: AGPL-3.0-or-later

use std::{env, net::SocketAddr, path::PathBuf, time::Duration};

use crate::{MemoryError, Result};

const DEFAULT_DATABASE_PATH: &str = "/data/memory.sqlite3";
const DEFAULT_BUSY_TIMEOUT_MS: u64 = 5_000;
const DEFAULT_BIND_ADDRESS: &str = "0.0.0.0:8000";
const DEFAULT_EMBEDDING_MODEL_PATH: &str = "/models/multilingual-e5-small-q8_0.gguf";
const DEFAULT_EMBEDDING_QUEUE_CAPACITY: usize = 32;
const DEFAULT_RECONCILE_INTERVAL_SECONDS: u64 = 30;
const DEFAULT_RECONCILE_BATCH_SIZE: u32 = 64;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Config {
    pub database_path: PathBuf,
    pub busy_timeout: Duration,
    pub bind_address: SocketAddr,
    pub embedding_model_path: PathBuf,
    pub embedding_version: String,
    pub embedding_threads: usize,
    pub embedding_queue_capacity: usize,
    pub reconcile_interval: Duration,
    pub reconcile_batch_size: u32,
}

impl Config {
    /// Loads process configuration from `POCKET_MEMORY_*` environment variables.
    ///
    /// # Errors
    ///
    /// Returns an error when an environment value cannot be parsed.
    pub fn from_env() -> Result<Self> {
        let database_path = env::var_os("POCKET_MEMORY_DATABASE_PATH")
            .map_or_else(|| PathBuf::from(DEFAULT_DATABASE_PATH), PathBuf::from);
        let busy_timeout = env::var("POCKET_MEMORY_BUSY_TIMEOUT_MS").map_or(
            Ok(DEFAULT_BUSY_TIMEOUT_MS),
            |value| {
                value.parse::<u64>().map_err(|error| {
                    MemoryError::Configuration(format!(
                        "POCKET_MEMORY_BUSY_TIMEOUT_MS must be an unsigned integer: {error}"
                    ))
                })
            },
        )?;
        let bind_address = env::var("POCKET_MEMORY_BIND_ADDRESS")
            .unwrap_or_else(|_| DEFAULT_BIND_ADDRESS.to_owned())
            .parse::<SocketAddr>()
            .map_err(|error| {
                MemoryError::Configuration(format!(
                    "POCKET_MEMORY_BIND_ADDRESS must be an IP socket address: {error}"
                ))
            })?;
        let embedding_model_path = env::var_os("POCKET_MEMORY_EMBEDDING_MODEL_PATH").map_or_else(
            || PathBuf::from(DEFAULT_EMBEDDING_MODEL_PATH),
            PathBuf::from,
        );
        let embedding_version = env::var("POCKET_MEMORY_EMBEDDING_VERSION")
            .unwrap_or_else(|_| crate::embedding::MODEL_VERSION.to_owned());
        if embedding_version.trim().is_empty() {
            return Err(MemoryError::Configuration(
                "POCKET_MEMORY_EMBEDDING_VERSION must not be empty".to_owned(),
            ));
        }
        let default_threads =
            std::thread::available_parallelism().map_or(4, |count| count.get().min(4));
        let embedding_threads = parse_positive("POCKET_MEMORY_EMBEDDING_THREADS", default_threads)?;
        let embedding_queue_capacity = parse_positive(
            "POCKET_MEMORY_EMBEDDING_QUEUE_CAPACITY",
            DEFAULT_EMBEDDING_QUEUE_CAPACITY,
        )?;
        let reconcile_interval_seconds = parse_positive(
            "POCKET_MEMORY_RECONCILE_INTERVAL_SECONDS",
            DEFAULT_RECONCILE_INTERVAL_SECONDS,
        )?;
        let reconcile_batch_size = parse_positive(
            "POCKET_MEMORY_RECONCILE_BATCH_SIZE",
            DEFAULT_RECONCILE_BATCH_SIZE,
        )?;

        Ok(Self {
            database_path,
            busy_timeout: Duration::from_millis(busy_timeout),
            bind_address,
            embedding_model_path,
            embedding_version,
            embedding_threads,
            embedding_queue_capacity,
            reconcile_interval: Duration::from_secs(reconcile_interval_seconds),
            reconcile_batch_size,
        })
    }
}

fn parse_positive<T>(name: &str, default: T) -> Result<T>
where
    T: std::str::FromStr + PartialEq + Default,
    T::Err: std::fmt::Display,
{
    let value = env::var(name).map_or(Ok(default), |value| {
        value.parse::<T>().map_err(|error| {
            MemoryError::Configuration(format!("{name} has an invalid value: {error}"))
        })
    })?;
    if value == T::default() {
        Err(MemoryError::Configuration(format!(
            "{name} must be greater than zero"
        )))
    } else {
        Ok(value)
    }
}
