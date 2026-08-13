// SPDX-License-Identifier: AGPL-3.0-or-later

mod llama;
mod reconcile;

use async_trait::async_trait;

use crate::Result;

pub use llama::{LlamaEmbedder, LlamaEmbedderConfig};
pub use reconcile::{ReconcileReport, reconcile_pending};

pub const MODEL_ID: &str = "intfloat/multilingual-e5-small";
pub const MODEL_VERSION: &str = "intfloat-multilingual-e5-small-q8_0-v1";
pub const QUERY_PREFIX: &str = "query: ";
pub const DOCUMENT_PREFIX: &str = "passage: ";

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum EmbeddingPurpose {
    Query,
    Document,
}

impl EmbeddingPurpose {
    fn prefix(self) -> &'static str {
        match self {
            Self::Query => QUERY_PREFIX,
            Self::Document => DOCUMENT_PREFIX,
        }
    }
}

#[async_trait]
pub trait Embedder: Send + Sync + 'static {
    fn version(&self) -> &str;

    async fn embed(&self, purpose: EmbeddingPurpose, texts: &[String]) -> Result<Vec<Vec<f32>>>;
}

pub(crate) fn prefixed_text(purpose: EmbeddingPurpose, text: &str) -> String {
    let mut prefixed = String::with_capacity(purpose.prefix().len() + text.len());
    prefixed.push_str(purpose.prefix());
    prefixed.push_str(text);
    prefixed
}

pub(crate) fn normalize(mut vector: Vec<f32>) -> Result<Vec<f32>> {
    let norm_squared = vector.iter().map(|value| value * value).sum::<f32>();
    if vector.iter().any(|value| !value.is_finite())
        || !norm_squared.is_finite()
        || norm_squared < 1.0e-12
    {
        return Err(crate::MemoryError::InvalidEmbedding);
    }
    let inverse_norm = norm_squared.sqrt().recip();
    for value in &mut vector {
        *value *= inverse_norm;
    }
    Ok(vector)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn e5_prefixes_are_owned_by_the_adapter() {
        assert_eq!(
            prefixed_text(EmbeddingPurpose::Query, "hola"),
            "query: hola"
        );
        assert_eq!(
            prefixed_text(EmbeddingPurpose::Document, "bonjour"),
            "passage: bonjour"
        );
    }

    #[test]
    fn normalization_produces_unit_vectors() {
        let normalized = normalize(vec![3.0, 4.0]).unwrap();
        assert!((normalized[0] - 0.6).abs() < 1.0e-6);
        assert!((normalized[1] - 0.8).abs() < 1.0e-6);
    }
}
