// SPDX-License-Identifier: AGPL-3.0-or-later

use pocket_memory::{AgentIdentity, MemoryKind, Repository, domain::TimestampFilter};

fn author(account: &str, profile: &str) -> AgentIdentity {
    AgentIdentity::new(account, profile, profile).unwrap()
}

#[tokio::test]
async fn fts_tracks_create_body_update_and_delete() {
    let repository = Repository::open_in_memory().await.unwrap();
    let record = repository
        .create(
            MemoryKind::Observation,
            &author("family", "poco"),
            "The café serves cardamom buns",
            1,
        )
        .await
        .unwrap();

    let initial = repository
        .fts_candidates(
            MemoryKind::Observation,
            "family",
            None,
            TimestampFilter::default(),
            "cafe",
            10,
        )
        .await
        .unwrap();
    assert_eq!(initial[0].record.id, record.id);

    repository
        .update_body(
            MemoryKind::Observation,
            "family",
            &record.id,
            "The bakery now serves rye bread",
            2,
        )
        .await
        .unwrap();
    assert!(
        repository
            .fts_candidates(
                MemoryKind::Observation,
                "family",
                None,
                TimestampFilter::default(),
                "cardamom",
                10
            )
            .await
            .unwrap()
            .is_empty()
    );
    assert_eq!(
        repository
            .fts_candidates(
                MemoryKind::Observation,
                "family",
                None,
                TimestampFilter::default(),
                "rye",
                10
            )
            .await
            .unwrap()[0]
            .record
            .id,
        record.id
    );

    repository
        .delete(MemoryKind::Observation, "family", &record.id)
        .await
        .unwrap();
    assert!(
        repository
            .fts_candidates(
                MemoryKind::Observation,
                "family",
                None,
                TimestampFilter::default(),
                "rye",
                10
            )
            .await
            .unwrap()
            .is_empty()
    );
}

#[tokio::test]
async fn fts_respects_account_and_author_filters() {
    let repository = Repository::open_in_memory().await.unwrap();
    let poco_author = author("family", "poco");
    let scout_author = author("family", "scout");
    let outsider = author("other", "poco");
    let poco_source = repository
        .create(MemoryKind::Observation, &poco_author, "poco source", 0)
        .await
        .unwrap();
    let scout_source = repository
        .create(MemoryKind::Observation, &scout_author, "scout source", 0)
        .await
        .unwrap();
    let outsider_source = repository
        .create(MemoryKind::Observation, &outsider, "other source", 0)
        .await
        .unwrap();
    let poco = repository
        .create_interpretation_with_links(&poco_author, "shared keyword", &[poco_source.id], 1)
        .await
        .unwrap();
    repository
        .create_interpretation_with_links(&scout_author, "shared keyword", &[scout_source.id], 2)
        .await
        .unwrap();
    repository
        .create_interpretation_with_links(&outsider, "shared keyword", &[outsider_source.id], 3)
        .await
        .unwrap();

    let matches = repository
        .fts_candidates(
            MemoryKind::Interpretation,
            "family",
            Some("poco"),
            TimestampFilter::default(),
            "shared",
            10,
        )
        .await
        .unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].record.id, poco.id);
}

#[tokio::test]
async fn fts_respects_explicit_timestamp_filters() {
    let repository = Repository::open_in_memory().await.unwrap();
    let identity = author("family", "poco");
    repository
        .create(MemoryKind::Observation, &identity, "shared earlier", 10)
        .await
        .unwrap();
    let later = repository
        .create(MemoryKind::Observation, &identity, "shared later", 20)
        .await
        .unwrap();

    let matches = repository
        .fts_candidates(
            MemoryKind::Observation,
            "family",
            None,
            TimestampFilter {
                created_after_ms: Some(15),
                ..TimestampFilter::default()
            },
            "shared",
            10,
        )
        .await
        .unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].record.id, later.id);
}
