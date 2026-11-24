// SPDX-License-Identifier: AGPL-3.0-or-later

// Compares the configured model with embeddings from the upstream
// intfloat/multilingual-e5-small ONNX model. A GGUF packaged with the wrong
// tokenizer still produces finite, normalized vectors, so only a comparison
// with known-good output catches it. Skipped without a model path.

use std::path::PathBuf;

use pocket_memory::embedding::{Embedder, EmbeddingPurpose, LlamaEmbedder, LlamaEmbedderConfig};
use serde::Deserialize;

#[derive(Deserialize)]
struct Reference {
    text: String,
    embedding: Vec<f32>,
}

#[tokio::test]
async fn configured_model_matches_upstream_and_survives_long_text() {
    let Some(path) = std::env::var_os("POCKET_MEMORY_TEST_MODEL_PATH") else {
        return;
    };
    let references: Vec<Reference> =
        serde_json::from_str(include_str!("fixtures/reference_embeddings.json")).unwrap();
    let embedder = tokio::task::spawn_blocking(move || {
        LlamaEmbedder::start(LlamaEmbedderConfig::new(PathBuf::from(path)))
    })
    .await
    .unwrap()
    .unwrap();
    for reference in references {
        let vectors = embedder
            .embed(
                EmbeddingPurpose::Document,
                std::slice::from_ref(&reference.text),
            )
            .await
            .unwrap();
        let cosine: f32 = vectors[0]
            .iter()
            .zip(&reference.embedding)
            .map(|(left, right)| left * right)
            .sum();
        assert!(
            cosine > 0.99,
            "{:?} has cosine {cosine} to upstream; is the tokenizer right?",
            reference.text
        );
    }

    // A long body must be cut to the model's context, not crash the process.
    // Kept in this test because llama.cpp can only start once per process.
    let long = "The quick brown fox jumps over the lazy dog. ".repeat(400);
    let vectors = embedder
        .embed(EmbeddingPurpose::Document, &[long, "short".to_owned()])
        .await
        .unwrap();
    assert_eq!(vectors.len(), 2);
}
