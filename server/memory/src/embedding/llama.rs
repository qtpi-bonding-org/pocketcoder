// SPDX-License-Identifier: AGPL-3.0-or-later

use std::{
    num::NonZeroU32,
    path::PathBuf,
    sync::{Arc, mpsc as std_mpsc},
    thread,
};

use async_trait::async_trait;
use llama_cpp_2::{
    context::{
        LlamaContext,
        params::{LlamaContextParams, LlamaPoolingType},
    },
    llama_backend::LlamaBackend,
    llama_batch::LlamaBatch,
    model::{AddBos, LlamaModel, params::LlamaModelParams},
    token::LlamaToken,
};
use tokio::sync::{mpsc, oneshot};

use super::{Embedder, EmbeddingPurpose, normalize, prefixed_text};
use crate::{MemoryError, Result, db::EMBEDDING_DIMENSION};

const CONTEXT_TOKENS: u32 = 512;
const MAX_SEQUENCES: usize = 8;
const DEFAULT_QUEUE_CAPACITY: usize = 32;

#[derive(Clone, Debug)]
pub struct LlamaEmbedderConfig {
    pub model_path: PathBuf,
    pub model_version: String,
    pub threads: usize,
    pub queue_capacity: usize,
}

impl LlamaEmbedderConfig {
    #[must_use]
    pub fn new(model_path: PathBuf) -> Self {
        Self {
            model_path,
            model_version: super::MODEL_VERSION.to_owned(),
            threads: thread::available_parallelism().map_or(4, |count| count.get().min(4)),
            queue_capacity: DEFAULT_QUEUE_CAPACITY,
        }
    }
}

#[derive(Clone)]
pub struct LlamaEmbedder {
    sender: mpsc::Sender<Command>,
    version: Arc<str>,
}

struct Command {
    purpose: EmbeddingPurpose,
    texts: Vec<String>,
    response: oneshot::Sender<Result<Vec<Vec<f32>>>>,
}

impl LlamaEmbedder {
    /// Loads the model and starts its dedicated inference thread.
    ///
    /// The llama model and context never leave this thread, so the service does
    /// not need an unsafe `Send` wrapper for llama.cpp's context.
    ///
    /// # Errors
    ///
    /// Returns an error if configuration is invalid, the worker cannot start,
    /// or llama.cpp cannot load the model/context.
    pub fn start(config: LlamaEmbedderConfig) -> Result<Self> {
        if config.queue_capacity == 0 {
            return Err(MemoryError::Configuration(
                "embedding queue capacity must be greater than zero".to_owned(),
            ));
        }
        if config.threads == 0 || config.threads > i32::MAX as usize {
            return Err(MemoryError::Configuration(
                "embedding thread count must be between 1 and i32::MAX".to_owned(),
            ));
        }
        if config.model_version.trim().is_empty() {
            return Err(MemoryError::Configuration(
                "embedding model version must not be empty".to_owned(),
            ));
        }

        let version = Arc::<str>::from(config.model_version.clone());
        let (sender, receiver) = mpsc::channel(config.queue_capacity);
        let (ready_sender, ready_receiver) = std_mpsc::sync_channel(1);
        thread::Builder::new()
            .name("pocket-memory-embedder".to_owned())
            .spawn(move || run_worker(&config, receiver, &ready_sender))
            .map_err(|error| MemoryError::Embedding(format!("failed to start worker: {error}")))?;
        ready_receiver
            .recv()
            .map_err(|_| MemoryError::EmbedderUnavailable)??;
        Ok(Self { sender, version })
    }
}

#[async_trait]
impl Embedder for LlamaEmbedder {
    fn version(&self) -> &str {
        &self.version
    }

    async fn embed(&self, purpose: EmbeddingPurpose, texts: &[String]) -> Result<Vec<Vec<f32>>> {
        if texts.is_empty() {
            return Ok(Vec::new());
        }
        let (response, receive) = oneshot::channel();
        self.sender
            .send(Command {
                purpose,
                texts: texts.to_vec(),
                response,
            })
            .await
            .map_err(|_| MemoryError::EmbedderUnavailable)?;
        receive
            .await
            .map_err(|_| MemoryError::EmbedderUnavailable)?
    }
}

fn run_worker(
    config: &LlamaEmbedderConfig,
    mut receiver: mpsc::Receiver<Command>,
    ready: &std_mpsc::SyncSender<Result<()>>,
) {
    let initialization = initialize(config);
    let Ok((model, backend)) = initialization else {
        let _ = ready.send(initialization.map(|_| ()));
        return;
    };
    let mut context = match model.new_context(&backend, context_params(config.threads)) {
        Ok(context) => context,
        Err(error) => {
            let _ = ready.send(Err(MemoryError::Embedding(format!(
                "failed to create llama context: {error}"
            ))));
            return;
        }
    };
    if ready.send(Ok(())).is_err() {
        return;
    }

    while let Some(command) = receiver.blocking_recv() {
        let result = embed_batch(&model, &mut context, command.purpose, &command.texts);
        let _ = command.response.send(result);
    }
    drop(context);
    drop(model);
    drop(backend);
}

fn initialize(config: &LlamaEmbedderConfig) -> Result<(LlamaModel, LlamaBackend)> {
    if !config.model_path.is_file() {
        return Err(MemoryError::Embedding(format!(
            "embedding model does not exist: {}",
            config.model_path.display()
        )));
    }
    let mut backend = LlamaBackend::init()
        .map_err(|error| MemoryError::Embedding(format!("failed to initialize llama: {error}")))?;
    backend.void_logs();
    let model_params = LlamaModelParams::default().with_n_gpu_layers(0);
    let model = LlamaModel::load_from_file(&backend, &config.model_path, &model_params)
        .map_err(|error| MemoryError::Embedding(format!("failed to load llama model: {error}")))?;
    let dimension = usize::try_from(model.n_embd_out()).map_err(|_| {
        MemoryError::Embedding("model reported a negative embedding dimension".to_owned())
    })?;
    if dimension != EMBEDDING_DIMENSION {
        return Err(MemoryError::Embedding(format!(
            "model embedding dimension is {dimension}; expected {EMBEDDING_DIMENSION}"
        )));
    }
    Ok((model, backend))
}

fn context_params(threads: usize) -> LlamaContextParams {
    let threads = i32::try_from(threads).unwrap_or(i32::MAX);
    LlamaContextParams::default()
        .with_n_ctx(NonZeroU32::new(CONTEXT_TOKENS))
        .with_n_batch(CONTEXT_TOKENS)
        .with_n_ubatch(CONTEXT_TOKENS)
        .with_n_threads(threads)
        .with_n_threads_batch(threads)
        .with_embeddings(true)
        .with_pooling_type(LlamaPoolingType::Mean)
        .with_n_seq_max(u32::try_from(MAX_SEQUENCES).unwrap_or(u32::MAX))
        .with_kv_unified(true)
}

fn embed_batch(
    model: &LlamaModel,
    context: &mut LlamaContext<'_>,
    purpose: EmbeddingPurpose,
    texts: &[String],
) -> Result<Vec<Vec<f32>>> {
    let tokenized = texts
        .iter()
        .map(|text| tokenize(model, purpose, text))
        .collect::<Result<Vec<_>>>()?;
    let token_counts = tokenized.iter().map(Vec::len).collect::<Vec<_>>();
    let buckets = token_buckets(&token_counts, CONTEXT_TOKENS as usize, MAX_SEQUENCES);
    let mut embeddings = vec![Vec::new(); texts.len()];

    for bucket in buckets {
        let total_tokens = bucket.iter().map(|index| token_counts[*index]).sum();
        let sequence_count = i32::try_from(bucket.len())
            .map_err(|_| MemoryError::Embedding("embedding batch is too large".to_owned()))?;
        let mut batch = LlamaBatch::new(total_tokens, sequence_count);
        for (sequence_id, index) in bucket.iter().enumerate() {
            batch
                .add_sequence(
                    &tokenized[*index],
                    i32::try_from(sequence_id).unwrap_or(i32::MAX),
                    true,
                )
                .map_err(|error| {
                    MemoryError::Embedding(format!("failed to build batch: {error}"))
                })?;
        }
        context.clear_kv_cache();
        context
            .encode(&mut batch)
            .map_err(|error| MemoryError::Embedding(format!("llama encode failed: {error}")))?;
        for (sequence_id, index) in bucket.iter().enumerate() {
            let raw = context
                .embeddings_seq_ith(i32::try_from(sequence_id).unwrap_or(i32::MAX))
                .map_err(|error| {
                    MemoryError::Embedding(format!("failed to read embedding: {error}"))
                })?;
            if raw.len() != EMBEDDING_DIMENSION {
                return Err(MemoryError::InvalidEmbedding);
            }
            embeddings[*index] = normalize(raw.to_vec())?;
        }
    }
    Ok(embeddings)
}

fn tokenize(model: &LlamaModel, purpose: EmbeddingPurpose, text: &str) -> Result<Vec<LlamaToken>> {
    if text.trim().is_empty() {
        return Err(MemoryError::InvalidInput(
            "text to embed must not be empty".to_owned(),
        ));
    }
    let mut tokens = model
        .str_to_token(&prefixed_text(purpose, text), AddBos::Always)
        .map_err(|error| MemoryError::Embedding(format!("tokenization failed: {error}")))?;
    tokens.truncate(CONTEXT_TOKENS as usize);
    if tokens.is_empty() {
        return Err(MemoryError::Embedding(
            "tokenizer returned no tokens".to_owned(),
        ));
    }
    Ok(tokens)
}

fn token_buckets(counts: &[usize], token_limit: usize, sequence_limit: usize) -> Vec<Vec<usize>> {
    let mut buckets = Vec::new();
    let mut bucket = Vec::new();
    let mut bucket_tokens = 0;
    for (index, count) in counts.iter().copied().enumerate() {
        if !bucket.is_empty()
            && (bucket_tokens + count > token_limit || bucket.len() == sequence_limit)
        {
            buckets.push(std::mem::take(&mut bucket));
            bucket_tokens = 0;
        }
        bucket.push(index);
        bucket_tokens += count;
    }
    if !bucket.is_empty() {
        buckets.push(bucket);
    }
    buckets
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn buckets_respect_token_and_sequence_limits() {
        assert_eq!(
            token_buckets(&[200, 200, 200, 20, 20, 20], 512, 3),
            vec![vec![0, 1], vec![2, 3, 4], vec![5]]
        );
    }

    #[test]
    fn context_is_configured_for_full_window_mean_pooling() {
        let params = context_params(2);
        assert_eq!(params.n_ctx(), NonZeroU32::new(CONTEXT_TOKENS));
        assert_eq!(params.n_batch(), CONTEXT_TOKENS);
        assert_eq!(
            params.n_seq_max(),
            u32::try_from(MAX_SEQUENCES).unwrap_or(u32::MAX)
        );
        assert_eq!(params.pooling_type(), LlamaPoolingType::Mean);
        assert!(params.embeddings());
        assert!(params.kv_unified());
    }
}
