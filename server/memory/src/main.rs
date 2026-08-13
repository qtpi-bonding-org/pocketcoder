// SPDX-License-Identifier: AGPL-3.0-or-later

use std::sync::Arc;

use pocket_memory::{
    Repository,
    config::Config,
    embedding::{LlamaEmbedder, LlamaEmbedderConfig},
    mcp,
    service::MemoryService,
};
use tokio_util::sync::CancellationToken;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "pocket_memory=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let config = Config::from_env()?;
    let repository =
        Repository::open_with_busy_timeout(&config.database_path, config.busy_timeout).await?;
    let service = load_service(&config, repository.clone()).await;
    let cancellation = CancellationToken::new();
    let reconciliation = service.semantic_search_available().then(|| {
        tokio::spawn(reconcile_loop(
            service.clone(),
            cancellation.child_token(),
            config.reconcile_interval,
            config.reconcile_batch_size,
        ))
    });
    let router = mcp::router(service, cancellation.child_token());
    let listener = tokio::net::TcpListener::bind(config.bind_address).await?;

    tracing::info!(address = %config.bind_address, "pocket-memory listening");
    let shutdown = cancellation.clone();
    axum::serve(listener, router)
        .with_graceful_shutdown(async move {
            shutdown_signal().await;
            shutdown.cancel();
        })
        .await?;

    cancellation.cancel();
    if let Some(reconciliation) = reconciliation {
        let _ = reconciliation.await;
    }
    repository.close().await?;
    Ok(())
}

async fn shutdown_signal() {
    #[cfg(unix)]
    {
        use tokio::signal::unix::{SignalKind, signal};

        let terminate = signal(SignalKind::terminate());
        if let Ok(mut terminate) = terminate {
            tokio::select! {
                _ = tokio::signal::ctrl_c() => {}
                _ = terminate.recv() => {}
            }
            return;
        }
    }

    let _ = tokio::signal::ctrl_c().await;
}

async fn load_service(config: &Config, repository: Repository) -> MemoryService {
    if !config.embedding_model_path.is_file() {
        tracing::warn!(
            path = %config.embedding_model_path.display(),
            "embedding model absent; starting with FTS-only search"
        );
        return MemoryService::new(repository);
    }

    let embedder_config = LlamaEmbedderConfig {
        model_path: config.embedding_model_path.clone(),
        model_version: config.embedding_version.clone(),
        threads: config.embedding_threads,
        queue_capacity: config.embedding_queue_capacity,
    };
    match tokio::task::spawn_blocking(move || LlamaEmbedder::start(embedder_config)).await {
        Ok(Ok(embedder)) => {
            tracing::info!(path = %config.embedding_model_path.display(), "embedding model ready");
            MemoryService::with_embedder(repository, Arc::new(embedder))
        }
        Ok(Err(error)) => {
            tracing::error!(error = %error, "embedding model failed; starting with FTS-only search");
            MemoryService::new(repository)
        }
        Err(error) => {
            tracing::error!(error = %error, "embedding startup task failed; starting with FTS-only search");
            MemoryService::new(repository)
        }
    }
}

async fn reconcile_loop(
    service: MemoryService,
    cancellation: CancellationToken,
    interval: std::time::Duration,
    batch_size: u32,
) {
    loop {
        match service.reconcile_pending(batch_size).await {
            Ok(Some(report)) if report.embedded > 0 || report.stale > 0 => {
                tracing::info!(
                    embedded = report.embedded,
                    stale = report.stale,
                    "reconciled memory embeddings"
                );
            }
            Ok(_) => {}
            Err(error) => tracing::warn!(error = %error, "embedding reconciliation failed"),
        }
        tokio::select! {
            () = cancellation.cancelled() => break,
            () = tokio::time::sleep(interval) => {}
        }
    }
}
