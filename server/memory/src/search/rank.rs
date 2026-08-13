// SPDX-License-Identifier: AGPL-3.0-or-later

use crate::domain::MemoryKind;

const RRF_K: f64 = 60.0;
const MILLIS_PER_DAY: f64 = 86_400_000.0;

#[derive(Clone, Debug, PartialEq)]
pub struct RankEvidence {
    pub kind: MemoryKind,
    pub id: String,
    pub fts_rank: Option<u32>,
    pub vector_rank: Option<u32>,
    pub vector_similarity: Option<f64>,
    pub updated_at: i64,
    pub retrieved_at: i64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RankingOptions {
    pub now_ms: i64,
    pub lambda: f64,
    pub deep_recall: bool,
    pub minimum_vector_similarity: f64,
    pub top_k: usize,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RankedMemory {
    pub kind: MemoryKind,
    pub id: String,
    pub fts_rank: Option<u32>,
    pub vector_rank: Option<u32>,
    pub vector_similarity: Option<f64>,
    pub updated_at: i64,
    pub rrf_score: f64,
    pub temporal_multiplier: f64,
    pub score: f64,
}

/// Fuses independent FTS/vector ranks and applies optional retrieval-time decay.
///
/// A lexical match always passes the relevance gate. A vector-only match must
/// reach `minimum_vector_similarity`; recency cannot rescue irrelevant content.
#[must_use]
pub fn rank_candidates(
    candidates: impl IntoIterator<Item = RankEvidence>,
    options: RankingOptions,
) -> Vec<RankedMemory> {
    if options.top_k == 0 || !options.lambda.is_finite() || options.lambda < 0.0 {
        return Vec::new();
    }

    let mut ranked = candidates
        .into_iter()
        .filter(|candidate| passes_relevance_gate(candidate, options.minimum_vector_similarity))
        .map(|candidate| {
            let rrf_score = rrf(candidate.fts_rank) + rrf(candidate.vector_rank);
            let temporal_multiplier = if options.deep_recall {
                1.0
            } else {
                let age_ms = options.now_ms.saturating_sub(candidate.retrieved_at).max(0);
                let age_days =
                    std::time::Duration::from_millis(u64::try_from(age_ms).unwrap_or(u64::MAX))
                        .as_secs_f64()
                        / (MILLIS_PER_DAY / 1_000.0);
                (-options.lambda * age_days).exp()
            };
            RankedMemory {
                kind: candidate.kind,
                id: candidate.id,
                fts_rank: candidate.fts_rank,
                vector_rank: candidate.vector_rank,
                vector_similarity: candidate.vector_similarity,
                updated_at: candidate.updated_at,
                rrf_score,
                temporal_multiplier,
                score: rrf_score * temporal_multiplier,
            }
        })
        .collect::<Vec<_>>();

    ranked.sort_by(|left, right| {
        right
            .score
            .total_cmp(&left.score)
            .then_with(|| right.updated_at.cmp(&left.updated_at))
            .then_with(|| kind_order(left.kind).cmp(&kind_order(right.kind)))
            .then_with(|| left.id.cmp(&right.id))
    });
    ranked.truncate(options.top_k);
    ranked
}

fn passes_relevance_gate(candidate: &RankEvidence, minimum_vector_similarity: f64) -> bool {
    candidate.fts_rank.is_some()
        || candidate
            .vector_similarity
            .is_some_and(|similarity| similarity >= minimum_vector_similarity)
}

fn rrf(rank: Option<u32>) -> f64 {
    rank.map_or(0.0, |rank| 1.0 / (RRF_K + f64::from(rank) + 1.0))
}

fn kind_order(kind: MemoryKind) -> u8 {
    match kind {
        MemoryKind::Observation => 0,
        MemoryKind::Interpretation => 1,
    }
}
