// SPDX-License-Identifier: AGPL-3.0-or-later

use std::fmt;

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use crate::{MemoryError, Result};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, JsonSchema)]
pub struct AgentIdentity {
    pub account_id: String,
    pub agent_profile_id: String,
    pub agent_name: String,
}

impl AgentIdentity {
    /// Constructs and validates an attributed PocketBase account/profile identity.
    ///
    /// # Errors
    ///
    /// Returns an error when any required identity field is blank.
    pub fn new(
        account_id: impl Into<String>,
        agent_profile_id: impl Into<String>,
        agent_name: impl Into<String>,
    ) -> Result<Self> {
        let identity = Self {
            account_id: account_id.into(),
            agent_profile_id: agent_profile_id.into(),
            agent_name: agent_name.into(),
        };
        identity.validate()?;
        Ok(identity)
    }

    /// Validates that every required identity field is non-empty.
    ///
    /// # Errors
    ///
    /// Returns an error naming the first blank field.
    pub fn validate(&self) -> Result<()> {
        for (field, value) in [
            ("account_id", self.account_id.as_str()),
            ("agent_profile_id", self.agent_profile_id.as_str()),
            ("agent_name", self.agent_name.as_str()),
        ] {
            if value.trim().is_empty() {
                return Err(MemoryError::InvalidInput(format!(
                    "identity field {field} must not be empty"
                )));
            }
        }
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum MemoryKind {
    Observation,
    Interpretation,
}

impl fmt::Display for MemoryKind {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Observation => formatter.write_str("observation"),
            Self::Interpretation => formatter.write_str("interpretation"),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, JsonSchema)]
pub struct MemoryRecord {
    pub id: String,
    pub account_id: String,
    pub agent_profile_id: String,
    pub agent_name: String,
    pub body: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub retrieved_at: i64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ListFilter {
    pub kind: MemoryKind,
    pub account_id: String,
    pub agent_profile_id: Option<String>,
    pub timestamps: TimestampFilter,
    pub limit: u32,
    pub offset: u32,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, Serialize, Deserialize, JsonSchema)]
pub struct TimestampFilter {
    pub created_after_ms: Option<i64>,
    pub created_before_ms: Option<i64>,
    pub updated_after_ms: Option<i64>,
    pub updated_before_ms: Option<i64>,
    pub retrieved_after_ms: Option<i64>,
    pub retrieved_before_ms: Option<i64>,
}

impl TimestampFilter {
    /// Rejects inverted time ranges.
    ///
    /// # Errors
    ///
    /// Returns an error when an `after` bound is greater than its matching
    /// `before` bound.
    pub fn validate(self) -> Result<()> {
        for (name, after, before) in [
            ("created", self.created_after_ms, self.created_before_ms),
            ("updated", self.updated_after_ms, self.updated_before_ms),
            (
                "retrieved",
                self.retrieved_after_ms,
                self.retrieved_before_ms,
            ),
        ] {
            if after
                .zip(before)
                .is_some_and(|(after, before)| after > before)
            {
                return Err(MemoryError::InvalidInput(format!(
                    "{name}_after_ms must not be greater than {name}_before_ms"
                )));
            }
        }
        Ok(())
    }

    #[must_use]
    pub fn is_empty(self) -> bool {
        self == Self::default()
    }
}
