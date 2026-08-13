// SPDX-License-Identifier: AGPL-3.0-or-later

use axum::http::{HeaderMap, HeaderName};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use serde::Deserialize;

use crate::{AgentIdentity, MemoryError, Result};

pub const MEMORY_CONTEXT_HEADER: HeaderName =
    HeaderName::from_static("x-pocketcoder-memory-context");
const MAX_CONTEXT_HEADER_BYTES: usize = 16 * 1024;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct WireIdentity {
    version: u8,
    account_id: String,
    agent_profile_id: String,
    agent_name: String,
}

/// Decodes and validates PocketBase's versioned attribution header.
///
/// # Errors
///
/// Returns an error when the header is absent, oversized, malformed, uses an
/// unsupported version, or contains an empty identity field.
pub fn decode_identity(headers: &HeaderMap) -> Result<AgentIdentity> {
    let encoded = headers
        .get(&MEMORY_CONTEXT_HEADER)
        .ok_or_else(|| MemoryError::InvalidIdentity("header is missing".to_owned()))?
        .to_str()
        .map_err(|_| MemoryError::InvalidIdentity("header is not ASCII".to_owned()))?;
    if encoded.len() > MAX_CONTEXT_HEADER_BYTES {
        return Err(MemoryError::InvalidIdentity(
            "header is too large".to_owned(),
        ));
    }
    let decoded = URL_SAFE_NO_PAD
        .decode(encoded)
        .map_err(|_| MemoryError::InvalidIdentity("header is not base64url".to_owned()))?;
    let wire: WireIdentity = serde_json::from_slice(&decoded)
        .map_err(|_| MemoryError::InvalidIdentity("header is not valid JSON".to_owned()))?;
    if wire.version != 1 {
        return Err(MemoryError::InvalidIdentity(format!(
            "unsupported version {}",
            wire.version
        )));
    }
    AgentIdentity::new(wire.account_id, wire.agent_profile_id, wire.agent_name)
        .map_err(|error| MemoryError::InvalidIdentity(error.to_string()))
}
