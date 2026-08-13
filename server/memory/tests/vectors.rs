// SPDX-License-Identifier: AGPL-3.0-or-later

use pocket_memory::{AgentIdentity, MemoryKind, Repository, domain::TimestampFilter};

fn unit_vector(axis: usize) -> Vec<f32> {
    let mut vector = vec![0.0; 384];
    vector[axis] = 1.0;
    vector
}

#[tokio::test]
async fn vectors_are_searchable_and_invalidated_by_body_updates() {
    let repository = Repository::open_in_memory().await.unwrap();
    let identity = AgentIdentity::new("family", "poco", "Poco").unwrap();
    let near = repository
        .create(MemoryKind::Observation, &identity, "near", 1)
        .await
        .unwrap();
    let far = repository
        .create(MemoryKind::Observation, &identity, "far", 2)
        .await
        .unwrap();
    repository
        .store_embedding(
            MemoryKind::Observation,
            "family",
            &near.id,
            "near",
            &unit_vector(0),
            "test-v1",
            3,
        )
        .await
        .unwrap();
    repository
        .store_embedding(
            MemoryKind::Observation,
            "family",
            &far.id,
            "far",
            &unit_vector(1),
            "test-v1",
            4,
        )
        .await
        .unwrap();

    let matches = repository
        .vector_candidates(
            MemoryKind::Observation,
            "family",
            None,
            TimestampFilter::default(),
            &unit_vector(0),
            10,
        )
        .await
        .unwrap();
    assert_eq!(matches[0].record.id, near.id);
    assert!(matches[0].similarity > 0.999);

    let filtered = repository
        .vector_candidates(
            MemoryKind::Observation,
            "family",
            None,
            TimestampFilter {
                created_after_ms: Some(2),
                ..TimestampFilter::default()
            },
            &unit_vector(0),
            10,
        )
        .await
        .unwrap();
    assert_eq!(filtered.len(), 1);
    assert_eq!(filtered[0].record.id, far.id);

    repository
        .update_body(MemoryKind::Observation, "family", &near.id, "changed", 5)
        .await
        .unwrap();
    let matches = repository
        .vector_candidates(
            MemoryKind::Observation,
            "family",
            None,
            TimestampFilter::default(),
            &unit_vector(0),
            10,
        )
        .await
        .unwrap();
    assert!(
        matches
            .iter()
            .all(|candidate| candidate.record.id != near.id)
    );

    let pending = repository
        .pending_embeddings(MemoryKind::Observation, "test-v1", 10)
        .await
        .unwrap();
    assert_eq!(pending.len(), 1);
    assert_eq!(pending[0].id, near.id);
}

#[tokio::test]
async fn stale_embedding_results_are_rejected() {
    let repository = Repository::open_in_memory().await.unwrap();
    let identity = AgentIdentity::new("family", "poco", "Poco").unwrap();
    let record = repository
        .create(MemoryKind::Interpretation, &identity, "before", 1)
        .await
        .unwrap();
    repository
        .update_body(MemoryKind::Interpretation, "family", &record.id, "after", 2)
        .await
        .unwrap();

    let error = repository
        .store_embedding(
            MemoryKind::Interpretation,
            "family",
            &record.id,
            "before",
            &unit_vector(0),
            "test-v1",
            3,
        )
        .await
        .unwrap_err();
    assert!(matches!(error, pocket_memory::MemoryError::StaleEmbedding));
}
