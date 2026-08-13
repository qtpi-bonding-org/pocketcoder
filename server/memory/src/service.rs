// SPDX-License-Identifier: AGPL-3.0-or-later

use std::{sync::Arc, time::SystemTime};

use schemars::JsonSchema;
use serde::Serialize;

use crate::{
    AgentIdentity, MemoryKind, MemoryRecord, Repository, Result,
    domain::ListFilter,
    search::{RankEvidence, RankingOptions, rank_candidates},
};

pub trait Clock: Send + Sync + 'static {
    fn now_ms(&self) -> i64;
}

#[derive(Debug)]
pub struct SystemClock;

impl Clock for SystemClock {
    fn now_ms(&self) -> i64 {
        let millis = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis();
        i64::try_from(millis).unwrap_or(i64::MAX)
    }
}

#[derive(Clone)]
pub struct MemoryService {
    repository: Repository,
    clock: Arc<dyn Clock>,
}

#[derive(Clone, Debug, Serialize, JsonSchema)]
pub struct MemoryWithLinks {
    pub record: MemoryRecord,
    pub linked: Vec<MemoryRecord>,
}

#[derive(Clone, Debug, Serialize, JsonSchema)]
pub struct SearchMatch {
    pub kind: MemoryKind,
    pub record: MemoryRecord,
    pub score: f64,
    pub fts_rank: Option<u32>,
    pub vector_rank: Option<u32>,
    pub vector_similarity: Option<f64>,
    pub temporal_multiplier: f64,
}

impl MemoryService {
    #[must_use]
    pub fn new(repository: Repository) -> Self {
        Self {
            repository,
            clock: Arc::new(SystemClock),
        }
    }

    #[must_use]
    pub fn with_clock(repository: Repository, clock: Arc<dyn Clock>) -> Self {
        Self { repository, clock }
    }

    /// Creates one observation attributed to the request identity.
    ///
    /// # Errors
    ///
    /// Propagates validation and repository errors.
    pub async fn create_observation(
        &self,
        identity: &AgentIdentity,
        body: String,
    ) -> Result<MemoryRecord> {
        self.repository
            .create(MemoryKind::Observation, identity, body, self.clock.now_ms())
            .await
    }

    /// Creates one interpretation and optional initial links atomically.
    ///
    /// # Errors
    ///
    /// Propagates validation, link-integrity, and repository errors.
    pub async fn create_interpretation(
        &self,
        identity: &AgentIdentity,
        body: String,
        observation_ids: &[String],
    ) -> Result<MemoryRecord> {
        self.repository
            .create_interpretation_with_links(identity, body, observation_ids, self.clock.now_ms())
            .await
    }

    /// Replaces a record body without changing original authorship.
    ///
    /// # Errors
    ///
    /// Propagates validation and repository errors.
    pub async fn update(
        &self,
        identity: &AgentIdentity,
        kind: MemoryKind,
        id: &str,
        body: String,
    ) -> Result<MemoryRecord> {
        self.repository
            .update_body(kind, &identity.account_id, id, body, self.clock.now_ms())
            .await
    }

    /// Deletes a canonical record inside the request account.
    ///
    /// # Errors
    ///
    /// Propagates not-found and repository errors.
    pub async fn delete(&self, identity: &AgentIdentity, kind: MemoryKind, id: &str) -> Result<()> {
        self.repository.delete(kind, &identity.account_id, id).await
    }

    /// Adds links inside the request account.
    ///
    /// # Errors
    ///
    /// Propagates record, account-consistency, and repository errors.
    pub async fn link(
        &self,
        identity: &AgentIdentity,
        interpretation_id: &str,
        observation_ids: &[String],
    ) -> Result<()> {
        self.repository
            .link(&identity.account_id, interpretation_id, observation_ids)
            .await
    }

    /// Removes links inside the request account.
    ///
    /// # Errors
    ///
    /// Propagates record, account-consistency, and repository errors.
    pub async fn unlink(
        &self,
        identity: &AgentIdentity,
        interpretation_id: &str,
        observation_ids: &[String],
    ) -> Result<()> {
        self.repository
            .unlink(&identity.account_id, interpretation_id, observation_ids)
            .await
    }

    /// Fetches a record and directly linked records.
    ///
    /// # Errors
    ///
    /// Propagates not-found and repository errors.
    pub async fn get(
        &self,
        identity: &AgentIdentity,
        kind: MemoryKind,
        id: &str,
    ) -> Result<MemoryWithLinks> {
        let record = self.repository.get(kind, &identity.account_id, id).await?;
        let linked_kind = match kind {
            MemoryKind::Observation => MemoryKind::Interpretation,
            MemoryKind::Interpretation => MemoryKind::Observation,
        };
        let linked_ids = self
            .repository
            .linked_ids(kind, &identity.account_id, id)
            .await?;
        let mut linked = Vec::with_capacity(linked_ids.len());
        for linked_id in linked_ids {
            linked.push(
                self.repository
                    .get(linked_kind, &identity.account_id, &linked_id)
                    .await?,
            );
        }
        Ok(MemoryWithLinks { record, linked })
    }

    /// Lists records inside the request account.
    ///
    /// # Errors
    ///
    /// Propagates validation and repository errors.
    pub async fn list(
        &self,
        identity: &AgentIdentity,
        kind: MemoryKind,
        agent_profile_id: Option<String>,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<MemoryRecord>> {
        self.repository
            .list(ListFilter {
                kind,
                account_id: identity.account_id.clone(),
                agent_profile_id,
                limit,
                offset,
            })
            .await
    }

    /// Performs lexical retrieval through the hybrid ranker's degraded path.
    ///
    /// # Errors
    ///
    /// Propagates query validation and repository errors.
    #[allow(clippy::too_many_arguments)]
    pub async fn search_fts_only(
        &self,
        identity: &AgentIdentity,
        query: &str,
        kind: Option<MemoryKind>,
        agent_profile_id: Option<&str>,
        top_k: u32,
        deep_recall: bool,
        lambda: f64,
    ) -> Result<Vec<SearchMatch>> {
        if top_k == 0 || top_k > 100 {
            return Err(crate::MemoryError::InvalidInput(
                "top_k must be between 1 and 100".to_owned(),
            ));
        }
        if !lambda.is_finite() || lambda < 0.0 {
            return Err(crate::MemoryError::InvalidInput(
                "lambda must be a finite non-negative number".to_owned(),
            ));
        }
        let now_ms = self.clock.now_ms();
        let candidate_limit = top_k.saturating_mul(4).max(40);
        let kinds = kind.map_or_else(
            || vec![MemoryKind::Observation, MemoryKind::Interpretation],
            |kind| vec![kind],
        );
        let mut candidates = Vec::new();
        for kind in kinds {
            for candidate in self
                .repository
                .fts_candidates(
                    kind,
                    &identity.account_id,
                    agent_profile_id,
                    query,
                    candidate_limit,
                )
                .await?
            {
                let record = candidate.record;
                candidates.push((
                    record.clone(),
                    RankEvidence {
                        kind,
                        id: record.id,
                        fts_rank: Some(candidate.rank),
                        vector_rank: None,
                        vector_similarity: None,
                        updated_at: record.updated_at,
                        retrieved_at: record.retrieved_at,
                    },
                ));
            }
        }
        let ranked = rank_candidates(
            candidates.iter().map(|(_, evidence)| evidence.clone()),
            RankingOptions {
                now_ms,
                lambda,
                deep_recall,
                minimum_vector_similarity: 1.0,
                top_k: usize::try_from(top_k).unwrap_or(usize::MAX),
            },
        );
        let mut matches = ranked
            .into_iter()
            .filter_map(|ranked| {
                candidates
                    .iter()
                    .find(|(record, evidence)| {
                        record.id == ranked.id && evidence.kind == ranked.kind
                    })
                    .map(|(record, _)| SearchMatch {
                        kind: ranked.kind,
                        record: record.clone(),
                        score: ranked.score,
                        fts_rank: ranked.fts_rank,
                        vector_rank: ranked.vector_rank,
                        vector_similarity: ranked.vector_similarity,
                        temporal_multiplier: ranked.temporal_multiplier,
                    })
            })
            .collect::<Vec<_>>();
        let touches = matches
            .iter()
            .map(|result| (result.kind, result.record.id.clone()))
            .collect::<Vec<_>>();
        self.repository
            .touch_retrieved(&identity.account_id, &touches, now_ms)
            .await?;
        for result in &mut matches {
            result.record.retrieved_at = now_ms;
        }
        Ok(matches)
    }
}
