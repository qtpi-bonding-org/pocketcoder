mod db;
mod embed;
mod tools;

use crate::db::Db;
use crate::embed::Embedder;
use crate::tools::PocoMemory;
use std::sync::Arc;
use tracing::info;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    // Config from env
    let surreal_url = std::env::var("SURREAL_URL").unwrap_or_else(|_| "ws://surrealdb:8000".to_string());
    // Strip protocol prefix — surrealdb crate Ws expects host:port only
    let surreal_addr = surreal_url
        .trim_start_matches("ws://")
        .trim_start_matches("wss://")
        .trim_end_matches("/rpc");
    let surreal_user = std::env::var("SURREAL_USER").unwrap_or_else(|_| "root".to_string());
    let surreal_pass = std::env::var("SURREAL_PASSWORD").unwrap_or_else(|_| "root".to_string());
    let surreal_ns = std::env::var("SURREAL_NAMESPACE").unwrap_or_else(|_| "poco_memory".to_string());
    let surreal_db = std::env::var("SURREAL_DATABASE").unwrap_or_else(|_| "poco_memory".to_string());
    let host = std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
    let port: u16 = std::env::var("PORT")
        .unwrap_or_else(|_| "8001".to_string())
        .parse()?;

    // Initialize components
    info!("initializing fastembed (AllMiniLML6V2)…");
    let embedder = Arc::new(Embedder::new()?);
    info!("fastembed ready");

    info!("connecting to SurrealDB at {surreal_addr}…");
    let db = Db::new(&surreal_addr, &surreal_user, &surreal_pass, &surreal_ns, &surreal_db).await?;
    info!("SurrealDB ready");

    // Build MCP service
    let db_clone = db.clone();
    let embedder_clone = Arc::clone(&embedder);

    let service = rmcp::transport::streamable_http_server::StreamableHttpService::new(
        move || Ok(PocoMemory::new(db_clone.clone(), Arc::clone(&embedder_clone))),
        rmcp::transport::streamable_http_server::session::local::LocalSessionManager::default()
            .into(),
        Default::default(),
    );

    // Health endpoint + MCP
    let health = axum::Router::new().route(
        "/health",
        axum::routing::get(|| async { "ok" }),
    );

    let app = health.nest_service("/mcp", service);

    let addr = format!("{host}:{port}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    info!("poco-memory listening on http://{addr}/mcp");

    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            tokio::signal::ctrl_c().await.ok();
            info!("shutting down");
        })
        .await?;

    Ok(())
}
