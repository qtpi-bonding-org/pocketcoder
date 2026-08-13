// SPDX-License-Identifier: AGPL-3.0-or-later

use pocket_memory::{
    AgentIdentity, MemoryError, MemoryKind, Repository,
    domain::{ListFilter, TimestampFilter},
};

fn poco(account: &str) -> AgentIdentity {
    AgentIdentity::new(account, "poco-profile", "Poco").expect("valid identity")
}

#[tokio::test]
async fn records_are_mutable_and_keep_original_authorship() {
    let repository = Repository::open_in_memory().await.expect("open database");
    let created = repository
        .create(MemoryKind::Observation, &poco("family"), "first", 100)
        .await
        .expect("create observation");

    let updated = repository
        .update_body(
            MemoryKind::Observation,
            "family",
            &created.id,
            "second",
            200,
        )
        .await
        .expect("update observation");

    assert_eq!(updated.body, "second");
    assert_eq!(updated.created_at, 100);
    assert_eq!(updated.updated_at, 200);
    assert_eq!(updated.retrieved_at, 100);
    assert_eq!(updated.agent_profile_id, "poco-profile");
    assert_eq!(updated.agent_name, "Poco");
}

#[tokio::test]
async fn list_is_scoped_by_account_and_optionally_author() {
    let repository = Repository::open_in_memory().await.expect("open database");
    let poco_author = poco("family");
    let scout = AgentIdentity::new("family", "scout-profile", "Scout").unwrap();
    let outsider = poco("other");

    repository
        .create(MemoryKind::Observation, &poco_author, "poco", 100)
        .await
        .unwrap();
    repository
        .create(MemoryKind::Observation, &scout, "scout", 200)
        .await
        .unwrap();
    repository
        .create(MemoryKind::Observation, &outsider, "other", 300)
        .await
        .unwrap();

    let records = repository
        .list(ListFilter {
            kind: MemoryKind::Observation,
            account_id: "family".to_owned(),
            agent_profile_id: Some("scout-profile".to_owned()),
            timestamps: TimestampFilter::default(),
            limit: 10,
            offset: 0,
        })
        .await
        .unwrap();

    assert_eq!(records.len(), 1);
    assert_eq!(records[0].body, "scout");
}

#[tokio::test]
async fn operations_cannot_address_another_account() {
    let repository = Repository::open_in_memory().await.expect("open database");
    let observation = repository
        .create(MemoryKind::Observation, &poco("family"), "source", 99)
        .await
        .unwrap();
    let record = repository
        .create_interpretation_with_links(&poco("family"), "private", &[observation.id], 100)
        .await
        .unwrap();

    let error = repository
        .get(MemoryKind::Interpretation, "other", &record.id)
        .await
        .unwrap_err();
    assert!(matches!(error, MemoryError::NotFound { .. }));
}

#[tokio::test]
async fn delete_is_explicitly_not_found() {
    let repository = Repository::open_in_memory().await.expect("open database");
    let error = repository
        .delete(MemoryKind::Observation, "family", "missing")
        .await
        .unwrap_err();
    assert!(matches!(error, MemoryError::NotFound { .. }));
}
