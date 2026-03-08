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


/*
@pocketcoder-core: Sentinel Proxy. Rust-based bridge that hardens exec calls and provides MCP access.
*/

//! # Sentinel Proxy
//! Rust-based bridge that hardens execution calls and provides MCP access.
//!
//! This sentinel acts as the "Muscle" of the PocketCoder architecture,
//! ensuring that tools are executed within a secure sandbox environment.
//!
//! ## Core Components
//!
//! - **Execution Driver**: Manages tmux sessions and command execution in the sandbox.
//! - **MCP Proxy**: Bridges WebSocket-based Model Context Protocol requests.
//! - **Shell Bridge**: Implements the `pocketcoder shell` command-line interface.
//!
//! ## Architecture
//!
//! The proxy runs as a high-performance Rust service that exposes an SSE and WebSocket API.
//! It translates high-level AI intents into low-level sandbox commands while maintaining
//! isolation and security.

pub mod driver;
pub mod shell;

use std::env;
use std::sync::Arc;
use std::collections::HashMap;
use anyhow::Result;
use parking_lot::RwLock;
use tokio::sync::mpsc;
use uuid::Uuid;
use clap::{Parser, Subcommand};
use axum::{
    extract::{State, Query},
    response::{sse::{Event, Sse}, IntoResponse},
    routing::{get, post},
    Json, Router,
};
use std::pin::Pin;
use std::task::{Context, Poll};
use futures_util::stream::Stream;
use tokio_stream::StreamExt;
use tokio_stream::wrappers::ReceiverStream;

use crate::driver::{PocketCoderDriver, ExecRequest};

use serde::Deserialize;

/// Query parameters for established sessions.
#[derive(Deserialize)]
pub struct McpQuery {
    /// Optional session ID to resume or identify the connection
    #[serde(alias = "sessionId")]
    pub session_id: Option<String>,
}

// --------------------------------------------------------------------------
// CLI Definition
// --------------------------------------------------------------------------

#[derive(Parser)]
#[command(name = "pocketcoder")]
#[command(about = "Sovereign Proxy & Relay", version = "1.0")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the proxy server (MCP Relay + Execution Bridge)
    Server {
        #[arg(short, long, default_value = "3001")]
        port: String,
    },
    /// Run in shell bridge mode (client)
    Shell {
        #[arg(short, long)]
        command: Option<String>,
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
}

// --------------------------------------------------------------------------
// Server State & Core Handlers
// --------------------------------------------------------------------------

type SessionMap = Arc<RwLock<HashMap<String, mpsc::Sender<serde_json::Value>>>>;

pub struct AppState {
    pub sessions: SessionMap,
    pub driver: Arc<PocketCoderDriver>,
}

/// A stream wrapper that removes the session from the map when dropped (client disconnects).
struct CleanupStream<S> {
    inner: S,
    sessions: SessionMap,
    session_id: String,
}

impl<S: Stream + Unpin> Stream for CleanupStream<S> {
    type Item = S::Item;

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Option<Self::Item>> {
        Pin::new(&mut self.inner).poll_next(cx)
    }
}

impl<S> Drop for CleanupStream<S> {
    fn drop(&mut self) {
        tracing::info!("[Server/SSE] Session disconnected, cleaning up: {}", self.session_id);
        self.sessions.write().remove(&self.session_id);
    }
}

async fn health_handler() -> &'static str {
    "ok"
}

async fn sse_handler(
    State(state): State<Arc<AppState>>,
    Query(query): Query<McpQuery>,
) -> Sse<impl Stream<Item = Result<Event, std::convert::Infallible>>> {
    let session_id = query.session_id.unwrap_or_else(|| Uuid::new_v4().to_string());
    tracing::info!("[Server/SSE] New session: {}", session_id);
    let (tx, rx) = mpsc::channel(100);

    state.sessions.write().insert(session_id.clone(), tx);

    let stream = ReceiverStream::new(rx).map(|msg| {
        Ok(Event::default().data(msg.to_string()).event("message"))
    });

    let stream = CleanupStream {
        inner: stream,
        sessions: Arc::clone(&state.sessions),
        session_id,
    };

    Sse::new(stream)
}

async fn exec_handler(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<ExecRequest>,
) -> Json<serde_json::Value> {
    let cwd = if payload.cwd.is_empty() { "/workspace" } else { &payload.cwd };

    tracing::info!("[Server/Exec] Cmd: {} (Agent: {})", payload.cmd, payload.agent_name);
    match state.driver.exec(&payload.cmd, Some(cwd), &payload.agent_name).await {
        Ok(res) => Json(serde_json::json!({ "stdout": res.output, "exit_code": res.exit_code })),
        Err(e) => Json(serde_json::json!({ "error": e.to_string(), "exit_code": 1 })),
    }
}

// --------------------------------------------------------------------------
// Entry Point
// --------------------------------------------------------------------------

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();

    match cli.command {
        Commands::Server { port } => {
            let socket_path = env::var("TMUX_SOCKET").unwrap_or_else(|_| "/tmp/tmux/pocketcoder".to_string());
            let session_name = env::var("TMUX_SESSION").unwrap_or_else(|_| "pocketcoder".to_string());

            tracing::info!("[PocketCoder] Mode: SERVER (Port: {})", port);
            
            let driver = Arc::new(PocketCoderDriver::new(&socket_path, &session_name));
            let state = Arc::new(AppState {
                sessions: Arc::new(RwLock::new(HashMap::new())),
                driver,
            });

            let app = Router::new()
                .route("/sse", get(sse_handler))
                .route("/health", get(health_handler))
                .route("/exec", post(exec_handler))
                .layer(tower_http::cors::CorsLayer::permissive())
                .with_state(state);

            tracing::info!("[PocketCoder] Server components ready");
            
            let addr = format!("0.0.0.0:{}", port);
            tracing::info!("[PocketCoder] Main Gateway: {}", addr);

            let listener = tokio::net::TcpListener::bind(addr).await?;
            axum::serve(listener, app)
                .with_graceful_shutdown(shutdown_signal())
                .await?;
        },
        Commands::Shell { command, args } => {
            shell::run(command, args)?;
        }
    }

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c().await.expect("failed to install Ctrl+C handler");
    };
    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };
    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}