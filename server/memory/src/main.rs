// SPDX-License-Identifier: AGPL-3.0-or-later

use pocket_memory::{Repository, config::Config, mcp, service::MemoryService};
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
    let cancellation = CancellationToken::new();
    let router = mcp::router(
        MemoryService::new(repository.clone()),
        cancellation.child_token(),
    );
    let listener = tokio::net::TcpListener::bind(config.bind_address).await?;

    tracing::info!(address = %config.bind_address, "pocket-memory listening");
    axum::serve(listener, router)
        .with_graceful_shutdown(async move {
            if tokio::signal::ctrl_c().await.is_ok() {
                cancellation.cancel();
            }
        })
        .await?;

    repository.close().await?;
    Ok(())
}
