// SPDX-License-Identifier: AGPL-3.0-or-later

use std::{
    collections::HashMap,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::SystemTime,
};

use schemars::JsonSchema;
use serde::Serialize;

use crate::{
    AgentIdentity, MemoryKind, MemoryRecord, Repository, Result,
    domain::{ListFilter, TimestampFilter},
    embedding::{Embedder, EmbeddingPurpose, ReconcileReport, reconcile_pending},
    search::{RankEvidence, RankingOptions, rank_candidates},
};

const MINIMUM_VECTOR_SIMILARITY: f64 = 0.70;

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
    embedder: Option<Arc<dyn Embedder>>,
    semantic_healthy: Arc<AtomicBool>,
}

#[derive(Clone, Debug, Serialize, JsonSchema)]
pub struct MemoryWithLinks {
    pub record: MemoryRecord,
    pub linked: Vec<MemoryRecord>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum InterpretationObservation {
    ExistingObservation(String),
    NewObservation(String),
}

#[derive(Clone, Debug, Serialize, JsonSchema)]
pub struct SearchMatch {
    pub kind: MemoryKind,
    pub record: MemoryRecord,
    pub score: f64,
    pub linked: Vec<MemoryRecord>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub debug: Option<SearchDebug>,
}

#[derive(Clone, Debug, Serialize, JsonSchema)]
pub struct SearchDebug {
    pub fts_rank: Option<u32>,
    pub vector_rank: Option<u32>,
    pub vector_similarity: Option<f64>,
    pub rrf_score: f64,
    pub temporal_multiplier: f64,
    pub minimum_vector_similarity: f64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum SearchMode {
    Hybrid,
    DegradedFtsOnly,
}

#[derive(Clone, Debug, Serialize, JsonSchema)]
pub struct SearchOutput {
    pub mode: SearchMode,
    pub matches: Vec<SearchMatch>,
}

impl MemoryService {
    #[must_use]
    pub fn new(repository: Repository) -> Self {
        Self {
            repository,
            clock: Arc::new(SystemClock),
            embedder: None,
            semantic_healthy: Arc::new(AtomicBool::new(false)),
        }
    }

    #[must_use]
    pub fn with_clock(repository: Repository, clock: Arc<dyn Clock>) -> Self {
        Self {
            repository,
            clock,
            embedder: None,
            semantic_healthy: Arc::new(AtomicBool::new(false)),
        }
    }

    #[must_use]
    pub fn with_embedder(repository: Repository, embedder: Arc<dyn Embedder>) -> Self {
        Self {
            repository,
            clock: Arc::new(SystemClock),
            embedder: Some(embedder),
            semantic_healthy: Arc::new(AtomicBool::new(true)),
        }
    }

    #[must_use]
    pub fn with_clock_and_embedder(
        repository: Repository,
        clock: Arc<dyn Clock>,
        embedder: Arc<dyn Embedder>,
    ) -> Self {
        Self {
            repository,
            clock,
            embedder: Some(embedder),
            semantic_healthy: Arc::new(AtomicBool::new(true)),
        }
    }

    #[must_use]
    pub fn semantic_search_available(&self) -> bool {
        self.embedder.is_some() && self.semantic_healthy.load(Ordering::Relaxed)
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
        let record = self
            .repository
            .create(MemoryKind::Observation, identity, body, self.clock.now_ms())
            .await?;
        self.embed_record_best_effort(MemoryKind::Observation, &record)
            .await;
        Ok(record)
    }

    /// Creates one interpretation with either an existing observation or a new
    /// observation created in the same transaction. Additional links are
    /// optional and all observation links are equal.
    ///
    /// # Errors
    ///
    /// Propagates validation, link-integrity, and repository errors.
    pub async fn create_interpretation(
        &self,
        identity: &AgentIdentity,
        body: String,
        observation: InterpretationObservation,
        additional_observation_ids: &[String],
    ) -> Result<MemoryWithLinks> {
        let now_ms = self.clock.now_ms();
        let interpretation = match observation {
            InterpretationObservation::ExistingObservation(observation_id) => {
                let mut observation_ids = additional_observation_ids.to_vec();
                observation_ids.push(observation_id);
                self.repository
                    .create_interpretation_with_links(identity, body, &observation_ids, now_ms)
                    .await?
            }
            InterpretationObservation::NewObservation(observation_body) => {
                let (observation, interpretation) = self
                    .repository
                    .create_observation_with_interpretation(
                        identity,
                        observation_body,
                        body,
                        additional_observation_ids,
                        now_ms,
                    )
                    .await?;
                self.embed_record_best_effort(MemoryKind::Observation, &observation)
                    .await;
                interpretation
            }
        };
        self.embed_record_best_effort(MemoryKind::Interpretation, &interpretation)
            .await;
        self.get(identity, MemoryKind::Interpretation, &interpretation.id)
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
        let record = self
            .repository
            .update_body(kind, &identity.account_id, id, body, self.clock.now_ms())
            .await?;
        self.embed_record_best_effort(kind, &record).await;
        Ok(record)
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
        timestamps: TimestampFilter,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<MemoryRecord>> {
        self.repository
            .list(ListFilter {
                kind,
                account_id: identity.account_id.clone(),
                agent_profile_id,
                timestamps,
                limit,
                offset,
            })
            .await
    }

    /// Performs hybrid retrieval, degrading to lexical search if embedding fails.
    ///
    /// # Errors
    ///
    /// Propagates query validation and repository errors.
    #[allow(clippy::too_many_arguments)]
    pub async fn search(
        &self,
        identity: &AgentIdentity,
        query: &str,
        kind: Option<MemoryKind>,
        agent_profile_id: Option<&str>,
        timestamps: TimestampFilter,
        top_k: u32,
        deep_recall: bool,
        lambda: f64,
        debug: bool,
    ) -> Result<SearchOutput> {
        self.search_internal(
            identity,
            query,
            kind,
            agent_profile_id,
            timestamps,
            top_k,
            deep_recall,
            lambda,
            true,
            debug,
        )
        .await
    }

    /// Performs lexical-only retrieval, primarily for deterministic diagnostics.
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
        timestamps: TimestampFilter,
        top_k: u32,
        deep_recall: bool,
        lambda: f64,
    ) -> Result<Vec<SearchMatch>> {
        Ok(self
            .search_internal(
                identity,
                query,
                kind,
                agent_profile_id,
                timestamps,
                top_k,
                deep_recall,
                lambda,
                false,
                false,
            )
            .await?
            .matches)
    }

    /// Reconciles one bounded page of derived embeddings when semantic search is enabled.
    ///
    /// # Errors
    ///
    /// Propagates embedding and repository errors.
    pub async fn reconcile_pending(&self, limit_per_kind: u32) -> Result<Option<ReconcileReport>> {
        let Some(embedder) = &self.embedder else {
            return Ok(None);
        };
        let result = reconcile_pending(
            &self.repository,
            embedder.as_ref(),
            self.clock.clone(),
            limit_per_kind,
        )
        .await;
        self.semantic_healthy
            .store(result.is_ok(), Ordering::Relaxed);
        result.map(Some)
    }

    async fn embed_record_best_effort(&self, kind: MemoryKind, record: &MemoryRecord) {
        let Some(embedder) = &self.embedder else {
            return;
        };
        let result = async {
            let embeddings = embedder
                .embed(
                    EmbeddingPurpose::Document,
                    std::slice::from_ref(&record.body),
                )
                .await?;
            let embedding = embeddings.first().ok_or_else(|| {
                crate::MemoryError::Embedding("embedder returned no vector".to_owned())
            })?;
            self.repository
                .store_embedding(
                    kind,
                    &record.account_id,
                    &record.id,
                    &record.body,
                    embedding,
                    embedder.version(),
                    self.clock.now_ms(),
                )
                .await
        }
        .await;
        if let Err(error) = result {
            self.semantic_healthy.store(false, Ordering::Relaxed);
            tracing::warn!(kind = %kind, id = %record.id, error = %error, "memory saved but embedding is pending");
        } else {
            self.semantic_healthy.store(true, Ordering::Relaxed);
        }
    }

    #[allow(clippy::too_many_arguments)]
    #[allow(clippy::too_many_lines)]
    async fn search_internal(
        &self,
        identity: &AgentIdentity,
        query: &str,
        kind: Option<MemoryKind>,
        agent_profile_id: Option<&str>,
        timestamps: TimestampFilter,
        top_k: u32,
        deep_recall: bool,
        lambda: f64,
        use_semantic: bool,
        debug: bool,
    ) -> Result<SearchOutput> {
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
        timestamps.validate()?;
        let now_ms = self.clock.now_ms();
        let candidate_limit = top_k.saturating_mul(4).max(40);
        let kinds = kind.map_or_else(
            || vec![MemoryKind::Observation, MemoryKind::Interpretation],
            |kind| vec![kind],
        );
        let query_vector = if use_semantic {
            if let Some(embedder) = &self.embedder {
                match embedder
                    .embed(EmbeddingPurpose::Query, &[query.to_owned()])
                    .await
                {
                    Ok(mut embeddings) => {
                        let embedding = embeddings.pop();
                        self.semantic_healthy
                            .store(embedding.is_some(), Ordering::Relaxed);
                        embedding
                    }
                    Err(error) => {
                        self.semantic_healthy.store(false, Ordering::Relaxed);
                        tracing::warn!(error = %error, "semantic query failed; using FTS-only retrieval");
                        None
                    }
                }
            } else {
                None
            }
        } else {
            None
        };
        let mode = if query_vector.is_some() {
            SearchMode::Hybrid
        } else {
            SearchMode::DegradedFtsOnly
        };
        let mut candidates = HashMap::<(MemoryKind, String), (MemoryRecord, RankEvidence)>::new();
        for kind in kinds {
            for candidate in self
                .repository
                .fts_candidates(
                    kind,
                    &identity.account_id,
                    agent_profile_id,
                    timestamps,
                    query,
                    candidate_limit,
                )
                .await?
            {
                let record = candidate.record;
                candidates.insert(
                    (kind, record.id.clone()),
                    (
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
                    ),
                );
            }
            if let Some(query_vector) = &query_vector {
                for candidate in self
                    .repository
                    .vector_candidates(
                        kind,
                        &identity.account_id,
                        agent_profile_id,
                        timestamps,
                        query_vector,
                        candidate_limit,
                    )
                    .await?
                {
                    let key = (kind, candidate.record.id.clone());
                    candidates
                        .entry(key)
                        .and_modify(|(_, evidence)| {
                            evidence.vector_rank = Some(candidate.rank);
                            evidence.vector_similarity = Some(candidate.similarity);
                        })
                        .or_insert_with(|| {
                            let record = candidate.record;
                            (
                                record.clone(),
                                RankEvidence {
                                    kind,
                                    id: record.id,
                                    fts_rank: None,
                                    vector_rank: Some(candidate.rank),
                                    vector_similarity: Some(candidate.similarity),
                                    updated_at: record.updated_at,
                                    retrieved_at: record.retrieved_at,
                                },
                            )
                        });
                }
            }
        }
        let ranked = rank_candidates(
            candidates.values().map(|(_, evidence)| evidence.clone()),
            RankingOptions {
                now_ms,
                lambda,
                deep_recall,
                minimum_vector_similarity: MINIMUM_VECTOR_SIMILARITY,
                top_k: usize::try_from(top_k).unwrap_or(usize::MAX),
            },
        );
        let mut matches = Vec::with_capacity(ranked.len());
        for ranked in ranked {
            let Some((record, _)) = candidates.get(&(ranked.kind, ranked.id.clone())) else {
                continue;
            };
            let linked_kind = match ranked.kind {
                MemoryKind::Observation => MemoryKind::Interpretation,
                MemoryKind::Interpretation => MemoryKind::Observation,
            };
            let linked_ids = self
                .repository
                .linked_ids(ranked.kind, &identity.account_id, &ranked.id)
                .await?;
            let mut linked = Vec::with_capacity(linked_ids.len());
            for linked_id in linked_ids {
                linked.push(
                    self.repository
                        .get(linked_kind, &identity.account_id, &linked_id)
                        .await?,
                );
            }
            matches.push(SearchMatch {
                kind: ranked.kind,
                record: record.clone(),
                score: ranked.score,
                linked,
                debug: debug.then_some(SearchDebug {
                    fts_rank: ranked.fts_rank,
                    vector_rank: ranked.vector_rank,
                    vector_similarity: ranked.vector_similarity,
                    rrf_score: ranked.rrf_score,
                    temporal_multiplier: ranked.temporal_multiplier,
                    minimum_vector_similarity: MINIMUM_VECTOR_SIMILARITY,
                }),
            });
        }
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
        Ok(SearchOutput { mode, matches })
    }
}
