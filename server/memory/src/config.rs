// SPDX-License-Identifier: AGPL-3.0-or-later

use std::{env, net::SocketAddr, path::PathBuf, time::Duration};

use crate::{MemoryError, Result};

const DEFAULT_DATABASE_PATH: &str = "/data/memory.sqlite3";
const DEFAULT_BUSY_TIMEOUT_MS: u64 = 5_000;
const DEFAULT_BIND_ADDRESS: &str = "0.0.0.0:8000";

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Config {
    pub database_path: PathBuf,
    pub busy_timeout: Duration,
    pub bind_address: SocketAddr,
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

        Ok(Self {
            database_path,
            busy_timeout: Duration::from_millis(busy_timeout),
            bind_address,
        })
    }
}
