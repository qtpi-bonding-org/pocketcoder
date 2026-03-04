use fastembed::{EmbeddingModel, InitOptions, TextEmbedding};
use std::sync::Arc;

/// Wrapper around fastembed AllMiniLML6V2 (384 dimensions).
/// fastembed is synchronous — all calls go through spawn_blocking.
pub struct Embedder {
    model: Arc<TextEmbedding>,
}

impl Embedder {
    pub fn new() -> anyhow::Result<Self> {
        let model = TextEmbedding::try_new(InitOptions::new(EmbeddingModel::AllMiniLML6V2))?;
        Ok(Self {
            model: Arc::new(model),
        })
    }

    pub async fn embed(&self, text: &str) -> anyhow::Result<Vec<f32>> {
        let model = Arc::clone(&self.model);
        let text = text.to_string();
        let embeddings =
            tokio::task::spawn_blocking(move || model.embed(vec![text], None)).await??;
        embeddings
            .into_iter()
            .next()
            .ok_or_else(|| anyhow::anyhow!("fastembed returned no embeddings"))
    }
}
