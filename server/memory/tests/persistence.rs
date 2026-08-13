// SPDX-License-Identifier: AGPL-3.0-or-later

use pocket_memory::{AgentIdentity, MemoryKind, Repository, domain::ListFilter};

#[tokio::test]
async fn canonical_records_survive_close_and_reopen() {
    let directory = tempfile::tempdir().unwrap();
    let path = directory.path().join("memory.sqlite3");
    let identity = AgentIdentity::new("family", "poco", "Poco").unwrap();

    let repository = Repository::open(&path).await.unwrap();
    let created = repository
        .create(MemoryKind::Observation, &identity, "persistent", 1)
        .await
        .unwrap();
    repository.close().await.unwrap();

    let reopened = Repository::open(&path).await.unwrap();
    let loaded = reopened
        .get(MemoryKind::Observation, "family", &created.id)
        .await
        .unwrap();
    assert_eq!(loaded, created);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn concurrent_agents_do_not_lose_creates() {
    let repository = Repository::open_in_memory().await.unwrap();
    let mut tasks = Vec::new();
    for index in 0..32 {
        let repository = repository.clone();
        tasks.push(tokio::spawn(async move {
            let profile = format!("profile-{}", index % 2);
            let identity = AgentIdentity::new("family", &profile, &profile).unwrap();
            repository
                .create(
                    MemoryKind::Observation,
                    &identity,
                    format!("observation {index}"),
                    index,
                )
                .await
        }));
    }

    for task in tasks {
        task.await.unwrap().unwrap();
    }

    let records = repository
        .list(ListFilter {
            kind: MemoryKind::Observation,
            account_id: "family".to_owned(),
            agent_profile_id: None,
            limit: 100,
            offset: 0,
        })
        .await
        .unwrap();
    assert_eq!(records.len(), 32);
}
