/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Poco Agents Server. MCP server for multi-agent orchestration.
mod agent;
mod state;
mod tmux;
mod tools;

use crate::agent::OpenCodeAgent;
use crate::state::AgentStore;
use crate::tools::PocoAgents;
use std::path::PathBuf;
use std::sync::Arc;
use tracing::{info, warn};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    let host = std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
    let port: u16 = std::env::var("PORT")
        .unwrap_or_else(|_| "9888".to_string())
        .parse()?;
    let agents_dir = std::env::var("AGENTS_DIR").unwrap_or_else(|_| "/workspace/.agents".to_string());
    let tmux_socket = std::env::var("TMUX_SOCKET").unwrap_or_else(|_| "/tmp/tmux/pocketcoder".to_string());
    let tmux_session = std::env::var("TMUX_SESSION").unwrap_or_else(|_| "pocketcoder".to_string());
    let opencode_config = std::env::var("OPENCODE_CONFIG")
        .unwrap_or_else(|_| "/root/.config/opencode/opencode.json".to_string());

    // Ensure agents directory exists
    std::fs::create_dir_all(&agents_dir)?;

    // Build agent backend
    let cli_agent: Arc<dyn crate::agent::CliAgent> = Arc::new(OpenCodeAgent::new(PathBuf::from(&opencode_config)));

    // Recover state from filesystem + tmux
    info!("recovering agent state from {agents_dir}…");
    let store = AgentStore::recover(&agents_dir, &tmux_socket, &tmux_session).await;
    let store = Arc::new(store);
    info!("recovered {} agents", store.len().await);

    let store_clone = Arc::clone(&store);
    let cli_clone = Arc::clone(&cli_agent);
    let agents_dir_clone = agents_dir.clone();
    let tmux_socket_clone = tmux_socket.clone();
    let tmux_session_clone = tmux_session.clone();

    let service = rmcp::transport::streamable_http_server::StreamableHttpService::new(
        move || {
            Ok(PocoAgents::new(
                Arc::clone(&store_clone),
                Arc::clone(&cli_clone),
                agents_dir_clone.clone(),
                tmux_socket_clone.clone(),
                tmux_session_clone.clone(),
            ))
        },
        rmcp::transport::streamable_http_server::session::local::LocalSessionManager::default()
            .into(),
        Default::default(),
    );

    let health = axum::Router::new().route(
        "/health",
        axum::routing::get(|| async { "ok" }),
    );

    let app = health.nest_service("/mcp", service);

    let addr = format!("{host}:{port}");
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    info!("poco-agents listening on http://{addr}/mcp");

    let shutdown_notify = Arc::new(tokio::sync::Notify::new());
    let shutdown_notify_clone = Arc::clone(&shutdown_notify);

    // Force-exit task: once shutdown signal fires, allow 10s for drain then exit
    tokio::spawn(async move {
        shutdown_notify_clone.notified().await;
        tokio::time::sleep(std::time::Duration::from_secs(10)).await;
        warn!("graceful shutdown timed out after 10s, forcing exit");
        std::process::exit(1);
    });

    axum::serve(listener, app)
        .with_graceful_shutdown(async move {
            tokio::signal::ctrl_c().await.ok();
            info!("shutting down");
            shutdown_notify.notify_one();
        })
        .await?;

    Ok(())
}
