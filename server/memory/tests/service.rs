// SPDX-License-Identifier: AGPL-3.0-or-later

use std::sync::Arc;

use pocket_memory::{
    AgentIdentity, MemoryKind, Repository,
    service::{Clock, MemoryService},
};

struct FixedClock(i64);

impl Clock for FixedClock {
    fn now_ms(&self) -> i64 {
        self.0
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
        .search_fts_only(&identity, "cardamom", None, None, 10, false, 0.05)
        .await
        .unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].record.id, observation.id);
    assert_eq!(matches[0].record.retrieved_at, 999);

    let hydrated_only = repository
        .get(MemoryKind::Interpretation, "family", &linked.id)
        .await
        .unwrap();
    assert_eq!(hydrated_only.retrieved_at, 2);
}
