// SPDX-License-Identifier: AGPL-3.0-or-later

use std::path::PathBuf;

use pocket_memory::{
    db::EMBEDDING_DIMENSION,
    embedding::{Embedder, EmbeddingPurpose, LlamaEmbedder, LlamaEmbedderConfig},
};

#[tokio::test]
async fn configured_gguf_loads_and_embeds_multilingual_text() {
    let Some(path) = std::env::var_os("POCKET_MEMORY_TEST_MODEL_PATH") else {
        return;
    };
    let embedder = tokio::task::spawn_blocking(move || {
        LlamaEmbedder::start(LlamaEmbedderConfig::new(PathBuf::from(path)))
    })
    .await
    .unwrap()
    .unwrap();

    let vectors = embedder
        .embed(
            EmbeddingPurpose::Document,
            &[
                "remember the blue gate".to_owned(),
                "青い門を覚えて".to_owned(),
            ],
        )
        .await
        .unwrap();
    assert_eq!(vectors.len(), 2);
    for vector in vectors {
        assert_eq!(vector.len(), EMBEDDING_DIMENSION);
        assert!(vector.iter().all(|value| value.is_finite()));
        let norm = vector.iter().map(|value| value * value).sum::<f32>();
        assert!((norm - 1.0).abs() < 1.0e-4);
    }
}
