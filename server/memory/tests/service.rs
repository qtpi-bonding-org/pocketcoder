// SPDX-License-Identifier: AGPL-3.0-or-later

use std::sync::Arc;

use pocket_memory::{
    AgentIdentity, MemoryKind, Repository, Result,
    db::EMBEDDING_DIMENSION,
    domain::TimestampFilter,
    embedding::{Embedder, EmbeddingPurpose},
    service::{Clock, MemoryService, SearchMode},
};

struct FixedClock(i64);

impl Clock for FixedClock {
    fn now_ms(&self) -> i64 {
        self.0
    }
}

struct FixedEmbedder {
    fail: bool,
}

#[async_trait::async_trait]
impl Embedder for FixedEmbedder {
    fn version(&self) -> &'static str {
        "test-v1"
    }

    async fn embed(&self, _purpose: EmbeddingPurpose, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        if self.fail {
            return Err(pocket_memory::MemoryError::Embedding(
                "intentional test failure".to_owned(),
            ));
        }
        Ok(texts
            .iter()
            .map(|_| {
                let mut vector = vec![0.0; EMBEDDING_DIMENSION];
                vector[0] = 1.0;
                vector
            })
            .collect())
    }
}

#[tokio::test]
async fn search_touches_only_direct_returned_matches() {
    let repository = Repository::open_in_memory().await.unwrap();
    let identity = AgentIdentity::new("family", "poco", "Poco").unwrap();
    let observation = repository
        .create(
            MemoryKind::Observation,
            &identity,
            "cardamom observation",
            1,
        )
        .await
        .unwrap();
    let linked = repository
        .create_interpretation_with_links(
            &identity,
            "a linked thought without the query term",
            std::slice::from_ref(&observation.id),
            2,
        )
        .await
        .unwrap();
    let service = MemoryService::with_clock(repository.clone(), Arc::new(FixedClock(999)));

    let matches = service
        .search_fts_only(
            &identity,
            "cardamom",
            None,
            None,
            TimestampFilter::default(),
            10,
            false,
            0.05,
        )
        .await
        .unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].record.id, observation.id);
    assert_eq!(matches[0].record.retrieved_at, 999);
    assert_eq!(matches[0].linked.len(), 1);
    assert_eq!(matches[0].linked[0].id, linked.id);
    assert!(matches[0].debug.is_none());

    let hydrated_only = repository
        .get(MemoryKind::Interpretation, "family", &linked.id)
        .await
        .unwrap();
    assert_eq!(hydrated_only.retrieved_at, 2);
}

#[tokio::test]
async fn hybrid_search_finds_a_semantic_only_match() {
    let repository = Repository::open_in_memory().await.unwrap();
    let identity = AgentIdentity::new("family", "poco", "Poco").unwrap();
    let service = MemoryService::with_clock_and_embedder(
        repository,
        Arc::new(FixedClock(999)),
        Arc::new(FixedEmbedder { fail: false }),
    );
    let record = service
        .create_observation(&identity, "the cobalt entrance".to_owned())
        .await
        .unwrap();

    let output = service
        .search(
            &identity,
            "unrelated tokens",
            None,
            None,
            TimestampFilter::default(),
            10,
            true,
            0.05,
            true,
        )
        .await
        .unwrap();
    assert_eq!(output.mode, SearchMode::Hybrid);
    assert_eq!(output.matches.len(), 1);
    assert_eq!(output.matches[0].record.id, record.id);
    let debug = output.matches[0].debug.as_ref().unwrap();
    assert_eq!(debug.vector_rank, Some(0));
    assert_eq!(debug.fts_rank, None);
}

#[tokio::test]
async fn embedding_failure_does_not_lose_canonical_memory() {
    let repository = Repository::open_in_memory().await.unwrap();
    let identity = AgentIdentity::new("family", "poco", "Poco").unwrap();
    let service = MemoryService::with_clock_and_embedder(
        repository.clone(),
        Arc::new(FixedClock(999)),
        Arc::new(FixedEmbedder { fail: true }),
    );
    let record = service
        .create_observation(&identity, "persisted despite embedding".to_owned())
        .await
        .unwrap();

    let stored = repository
        .get(MemoryKind::Observation, "family", &record.id)
        .await
        .unwrap();
    assert_eq!(stored.body, "persisted despite embedding");
    let output = service
        .search(
            &identity,
            "persisted",
            None,
            None,
            TimestampFilter::default(),
            10,
            false,
            0.05,
            false,
        )
        .await
        .unwrap();
    assert_eq!(output.mode, SearchMode::DegradedFtsOnly);
    assert_eq!(output.matches[0].record.id, record.id);
}
