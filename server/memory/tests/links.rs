// SPDX-License-Identifier: AGPL-3.0-or-later

use pocket_memory::{AgentIdentity, MemoryError, MemoryKind, Repository, domain::TimestampFilter};

fn identity(account: &str, profile: &str) -> AgentIdentity {
    AgentIdentity::new(account, profile, profile).unwrap()
}

#[tokio::test]
async fn links_are_many_to_many_and_idempotent() {
    let repository = Repository::open_in_memory().await.unwrap();
    let author = identity("family", "poco");
    let observation_a = repository
        .create(MemoryKind::Observation, &author, "A", 1)
        .await
        .unwrap();
    let observation_b = repository
        .create(MemoryKind::Observation, &author, "B", 2)
        .await
        .unwrap();
    let interpretation_a = repository
        .create_interpretation_with_links(&author, "IA", std::slice::from_ref(&observation_a.id), 3)
        .await
        .unwrap();
    let interpretation_b = repository
        .create_interpretation_with_links(&author, "IB", std::slice::from_ref(&observation_a.id), 4)
        .await
        .unwrap();

    repository
        .link(
            "family",
            &interpretation_a.id,
            std::slice::from_ref(&observation_b.id),
        )
        .await
        .unwrap();
    repository
        .link(
            "family",
            &interpretation_a.id,
            std::slice::from_ref(&observation_a.id),
        )
        .await
        .unwrap();

    assert_eq!(
        repository
            .linked_ids(MemoryKind::Interpretation, "family", &interpretation_a.id)
            .await
            .unwrap(),
        vec![observation_a.id.clone(), observation_b.id]
    );
    assert_eq!(
        repository
            .linked_ids(MemoryKind::Observation, "family", &observation_a.id)
            .await
            .unwrap(),
        vec![interpretation_a.id.clone(), interpretation_b.id.clone()]
    );

    repository
        .unlink(
            "family",
            &interpretation_a.id,
            std::slice::from_ref(&observation_a.id),
        )
        .await
        .unwrap();
    assert_eq!(
        repository
            .linked_ids(MemoryKind::Observation, "family", &observation_a.id)
            .await
            .unwrap(),
        vec![interpretation_b.id]
    );
}

#[tokio::test]
async fn cross_account_links_are_rejected() {
    let repository = Repository::open_in_memory().await.unwrap();
    let family = identity("family", "poco");
    let source = repository
        .create(MemoryKind::Observation, &family, "source", 0)
        .await
        .unwrap();
    let interpretation = repository
        .create_interpretation_with_links(&family, "interpretation", &[source.id], 1)
        .await
        .unwrap();
    let observation = repository
        .create(
            MemoryKind::Observation,
            &identity("other", "poco"),
            "observation",
            2,
        )
        .await
        .unwrap();

    let error = repository
        .link("family", &interpretation.id, &[observation.id])
        .await
        .unwrap_err();
    assert!(matches!(error, MemoryError::CrossAccountLink));
}

#[tokio::test]
async fn interpretation_and_initial_links_are_one_transaction() {
    let repository = Repository::open_in_memory().await.unwrap();
    let family = identity("family", "poco");
    let observation = repository
        .create(MemoryKind::Observation, &family, "observation", 1)
        .await
        .unwrap();

    let interpretation = repository
        .create_interpretation_with_links(
            &family,
            "interpretation",
            std::slice::from_ref(&observation.id),
            2,
        )
        .await
        .unwrap();
    assert_eq!(
        repository
            .linked_ids(MemoryKind::Interpretation, "family", &interpretation.id)
            .await
            .unwrap(),
        vec![observation.id]
    );

    let other_observation = repository
        .create(
            MemoryKind::Observation,
            &identity("other", "poco"),
            "other observation",
            3,
        )
        .await
        .unwrap();
    let error = repository
        .create_interpretation_with_links(&family, "must roll back", &[other_observation.id], 4)
        .await
        .unwrap_err();
    assert!(matches!(error, MemoryError::CrossAccountLink));

    let interpretations = repository
        .list(pocket_memory::domain::ListFilter {
            kind: MemoryKind::Interpretation,
            account_id: "family".to_owned(),
            agent_profile_id: None,
            timestamps: TimestampFilter::default(),
            limit: 10,
            offset: 0,
        })
        .await
        .unwrap();
    assert_eq!(interpretations.len(), 1);

    let error = repository
        .create_interpretation_with_links(&family, "unsupported", &[], 5)
        .await
        .unwrap_err();
    assert!(matches!(error, MemoryError::InvalidInput(_)));
}

#[tokio::test]
async fn removing_observations_cannot_orphan_an_interpretation() {
    let repository = Repository::open_in_memory().await.unwrap();
    let author = identity("family", "poco");
    let observation_a = repository
        .create(MemoryKind::Observation, &author, "observation A", 1)
        .await
        .unwrap();
    let observation_b = repository
        .create(MemoryKind::Observation, &author, "observation B", 2)
        .await
        .unwrap();
    let interpretation = repository
        .create_interpretation_with_links(
            &author,
            "interpretation",
            std::slice::from_ref(&observation_a.id),
            3,
        )
        .await
        .unwrap();

    let unlink_error = repository
        .unlink(
            "family",
            &interpretation.id,
            std::slice::from_ref(&observation_a.id),
        )
        .await
        .unwrap_err();
    assert!(matches!(unlink_error, MemoryError::InvalidInput(_)));

    let delete_error = repository
        .delete(MemoryKind::Observation, "family", &observation_a.id)
        .await
        .unwrap_err();
    assert!(matches!(delete_error, MemoryError::InvalidInput(_)));

    repository
        .link(
            "family",
            &interpretation.id,
            std::slice::from_ref(&observation_b.id),
        )
        .await
        .unwrap();
    repository
        .delete(MemoryKind::Observation, "family", &observation_a.id)
        .await
        .unwrap();

    let survivor = repository
        .get(MemoryKind::Interpretation, "family", &interpretation.id)
        .await
        .unwrap();
    assert_eq!(survivor.body, "interpretation");
    assert_eq!(
        repository
            .linked_ids(MemoryKind::Interpretation, "family", &interpretation.id)
            .await
            .unwrap(),
        vec![observation_b.id]
    );
}

#[tokio::test]
async fn a_new_observation_and_interpretation_are_created_atomically() {
    let repository = Repository::open_in_memory().await.unwrap();
    let author = identity("family", "poco");
    let additional = repository
        .create(MemoryKind::Observation, &author, "additional", 1)
        .await
        .unwrap();

    let (created_observation, interpretation) = repository
        .create_observation_with_interpretation(
            &author,
            "new observation",
            "new interpretation",
            std::slice::from_ref(&additional.id),
            2,
        )
        .await
        .unwrap();

    let mut expected = vec![created_observation.id, additional.id];
    expected.sort();
    assert_eq!(
        repository
            .linked_ids(MemoryKind::Interpretation, "family", &interpretation.id)
            .await
            .unwrap(),
        expected
    );
}

#[tokio::test]
async fn batch_unlink_rolls_back_if_it_would_remove_every_observation() {
    let repository = Repository::open_in_memory().await.unwrap();
    let author = identity("family", "poco");
    let observation_a = repository
        .create(MemoryKind::Observation, &author, "A", 1)
        .await
        .unwrap();
    let observation_b = repository
        .create(MemoryKind::Observation, &author, "B", 2)
        .await
        .unwrap();
    let interpretation = repository
        .create_interpretation_with_links(
            &author,
            "interpretation",
            &[observation_a.id.clone(), observation_b.id.clone()],
            3,
        )
        .await
        .unwrap();

    let error = repository
        .unlink(
            "family",
            &interpretation.id,
            &[observation_a.id.clone(), observation_b.id.clone()],
        )
        .await
        .unwrap_err();
    assert!(matches!(error, MemoryError::InvalidInput(_)));

    let mut expected = vec![observation_a.id, observation_b.id];
    expected.sort();
    assert_eq!(
        repository
            .linked_ids(MemoryKind::Interpretation, "family", &interpretation.id)
            .await
            .unwrap(),
        expected
    );
}

#[tokio::test]
async fn deleting_an_interpretation_cascades_all_of_its_links() {
    let repository = Repository::open_in_memory().await.unwrap();
    let author = identity("family", "poco");
    let observation = repository
        .create(MemoryKind::Observation, &author, "source", 1)
        .await
        .unwrap();
    let interpretation = repository
        .create_interpretation_with_links(
            &author,
            "interpretation",
            std::slice::from_ref(&observation.id),
            2,
        )
        .await
        .unwrap();

    repository
        .delete(MemoryKind::Interpretation, "family", &interpretation.id)
        .await
        .unwrap();
    assert!(
        repository
            .linked_ids(MemoryKind::Observation, "family", &observation.id)
            .await
            .unwrap()
            .is_empty()
    );
}
