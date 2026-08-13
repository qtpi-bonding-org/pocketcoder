// SPDX-License-Identifier: AGPL-3.0-or-later

use pocket_memory::{
    MemoryKind,
    search::{RankEvidence, RankingOptions, rank_candidates},
};

const DAY_MS: i64 = 86_400_000;

fn evidence(id: &str, fts_rank: Option<u32>, vector_rank: Option<u32>) -> RankEvidence {
    RankEvidence {
        kind: MemoryKind::Observation,
        id: id.to_owned(),
        fts_rank,
        vector_rank,
        vector_similarity: vector_rank.map(|_| 0.9),
        updated_at: 1,
        retrieved_at: 10 * DAY_MS,
    }
}

fn options() -> RankingOptions {
    RankingOptions {
        now_ms: 10 * DAY_MS,
        lambda: 0.05,
        deep_recall: false,
        minimum_vector_similarity: 0.75,
        top_k: 10,
    }
}

#[test]
fn overlap_wins_reciprocal_rank_fusion() {
    let ranked = rank_candidates(
        [
            evidence("fts", Some(0), None),
            evidence("vector", None, Some(0)),
            evidence("both", Some(1), Some(1)),
        ],
        options(),
    );
    assert_eq!(ranked[0].id, "both");
}

#[test]
fn normal_recall_decays_but_deep_recall_does_not() {
    let mut old = evidence("old", Some(0), None);
    old.retrieved_at = 0;
    let recent = evidence("recent", Some(1), None);

    let ranked = rank_candidates([old.clone(), recent.clone()], options());
    assert_eq!(ranked[0].id, "recent");

    let ranked = rank_candidates(
        [old, recent],
        RankingOptions {
            deep_recall: true,
            ..options()
        },
    );
    assert_eq!(ranked[0].id, "old");
    assert!((ranked[0].temporal_multiplier - 1.0).abs() < f64::EPSILON);
}

#[test]
fn recency_cannot_rescue_irrelevant_vector_only_results() {
    let mut weak = evidence("weak", None, Some(0));
    weak.vector_similarity = Some(0.2);
    assert!(rank_candidates([weak], options()).is_empty());
}
