// SPDX-License-Identifier: AGPL-3.0-or-later

pub mod config;
pub mod db;
pub mod domain;
pub mod embedding;
pub mod error;
pub mod identity;
pub mod mcp;
pub mod search;
pub mod service;

pub use db::Repository;
pub use domain::{AgentIdentity, MemoryKind, MemoryRecord};
pub use error::{MemoryError, Result};
