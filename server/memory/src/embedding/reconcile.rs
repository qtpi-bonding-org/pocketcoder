// SPDX-License-Identifier: AGPL-3.0-or-later

use std::sync::Arc;

use super::{Embedder, EmbeddingPurpose};
use crate::{MemoryKind, Repository, Result, service::Clock};

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct ReconcileReport {
    pub embedded: u32,
    pub stale: u32,
}

/// Embeds one bounded page of missing or outdated derived rows.
///
/// # Errors
///
/// Returns repository or embedding failures. A concurrent canonical edit is
/// counted as stale and left for the next pass.
pub async fn reconcile_pending(
    repository: &Repository,
    embedder: &dyn Embedder,
    clock: Arc<dyn Clock>,
    limit_per_kind: u32,
) -> Result<ReconcileReport> {
    let mut report = ReconcileReport::default();
    for kind in [MemoryKind::Observation, MemoryKind::Interpretation] {
        let pending = repository
            .pending_embeddings(kind, embedder.version(), limit_per_kind)
            .await?;
        if pending.is_empty() {
            continue;
        }
        let bodies = pending
            .iter()
            .map(|item| item.body.clone())
            .collect::<Vec<_>>();
        let embeddings = embedder.embed(EmbeddingPurpose::Document, &bodies).await?;
        if embeddings.len() != pending.len() {
            return Err(crate::MemoryError::Embedding(format!(
                "embedder returned {} vectors for {} memories",
                embeddings.len(),
                pending.len()
            )));
        }
        for (item, embedding) in pending.into_iter().zip(embeddings) {
            match repository
                .store_embedding(
                    item.kind,
                    &item.account_id,
                    &item.id,
                    &item.body,
                    &embedding,
                    embedder.version(),
                    clock.now_ms(),
                )
                .await
            {
                Ok(()) => report.embedded += 1,
                Err(crate::MemoryError::StaleEmbedding) => report.stale += 1,
                Err(error) => return Err(error),
            }
        }
    }
    Ok(report)
}
