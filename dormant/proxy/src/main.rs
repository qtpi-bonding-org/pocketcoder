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
use std::fs::{self, File};
use std::path::{Component, Path, PathBuf};
use std::process::Stdio;
use anyhow::Result;
use parking_lot::RwLock;
use tokio::sync::mpsc;
use uuid::Uuid;
use clap::{Parser, Subcommand};
use axum::{
    extract::{Path as AxumPath, State, Query},
    http::StatusCode,
    response::sse::{Event, Sse},
    routing::{delete, get, post},
    Json, Router,
};
use std::pin::Pin;
use std::task::{Context, Poll};
use futures_util::stream::Stream;
use tokio_stream::StreamExt;
use tokio_stream::wrappers::ReceiverStream;

use crate::driver::{PocketCoderDriver, ExecRequest};

use serde::{Deserialize, Serialize};

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
    sessions: SessionMap,
    driver: Arc<PocketCoderDriver>,
    terminals: Arc<RwLock<HashMap<String, Terminal>>>,
}

const WORKSPACE_ROOT: &str = "/workspace";
const MAX_FILE_BYTES: u64 = 2 * 1024 * 1024;
const MAX_TERMINAL_OUTPUT_BYTES: usize = 2 * 1024 * 1024;

#[derive(Clone)]
struct Terminal {
    pid: u32,
    output_path: PathBuf,
    output_limit: usize,
    status: Arc<RwLock<Option<TerminalExit>>>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct TerminalExit {
    exit_code: Option<i32>,
    signal: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct FsReadRequest { path: String, line: Option<usize>, limit: Option<usize> }

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct FsWriteRequest { path: String, content: String }

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateTerminalRequest {
    command: String,
    #[serde(default)] args: Vec<String>,
    cwd: Option<String>,
    #[serde(default)] env: Vec<EnvVariable>,
    output_byte_limit: Option<usize>,
}

#[derive(Deserialize)]
struct EnvVariable { name: String, value: String }

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct TerminalCreated { terminal_id: String }

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct TerminalOutput { output: String, truncated: bool, exit_status: Option<TerminalExit> }

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

// ACP-specific endpoints intentionally do not call the legacy shell/tmux
// bridge. They are the only c1-facing execution surface and enforce the
// workspace root inside the sandbox container itself.
fn workspace_path(value: &str, must_exist: bool) -> Result<PathBuf, (StatusCode, String)> {
    let path = Path::new(value);
    if !path.is_absolute() || path.components().any(|part| matches!(part, Component::ParentDir)) {
        return Err((StatusCode::BAD_REQUEST, "path must be an absolute workspace path".into()));
    }
    let root = fs::canonicalize(WORKSPACE_ROOT)
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "workspace unavailable".into()))?;
    let candidate = if must_exist {
        fs::canonicalize(path).map_err(|_| (StatusCode::NOT_FOUND, "path not found".into()))?
    } else {
        let parent = path.parent().ok_or((StatusCode::BAD_REQUEST, "invalid path".into()))?;
        let canonical_parent = fs::canonicalize(parent)
            .map_err(|_| (StatusCode::BAD_REQUEST, "parent must exist inside workspace".into()))?;
        canonical_parent.join(path.file_name().ok_or((StatusCode::BAD_REQUEST, "invalid path".into()))?)
    };
    if !candidate.starts_with(&root) {
        return Err((StatusCode::FORBIDDEN, "path is outside /workspace".into()));
    }
    Ok(candidate)
}

async fn fs_read_handler(Json(request): Json<FsReadRequest>) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let path = workspace_path(&request.path, true)?;
    let metadata = fs::metadata(&path).map_err(|_| (StatusCode::NOT_FOUND, "path not found".into()))?;
    if !metadata.is_file() || metadata.len() > MAX_FILE_BYTES {
        return Err((StatusCode::BAD_REQUEST, "path must be a text file no larger than 2 MiB".into()));
    }
    let content = fs::read_to_string(path).map_err(|_| (StatusCode::BAD_REQUEST, "file is not valid UTF-8 text".into()))?;
    let lines: Vec<&str> = content.lines().collect();
    let start = request.line.unwrap_or(1).saturating_sub(1);
    let end = request.limit.map(|limit| start.saturating_add(limit)).unwrap_or(lines.len()).min(lines.len());
    Ok(Json(serde_json::json!({"content": if start >= lines.len() { String::new() } else { lines[start..end].join("\n") }})))
}

async fn fs_write_handler(Json(request): Json<FsWriteRequest>) -> Result<StatusCode, (StatusCode, String)> {
    if request.content.len() > MAX_FILE_BYTES as usize { return Err((StatusCode::PAYLOAD_TOO_LARGE, "content exceeds 2 MiB".into())); }
    let path = workspace_path(&request.path, false)?;
    fs::write(path, request.content).map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "write failed".into()))?;
    Ok(StatusCode::NO_CONTENT)
}

fn safe_env_name(name: &str) -> bool {
    !name.is_empty() && name.chars().enumerate().all(|(i, c)| (i == 0 && (c.is_ascii_alphabetic() || c == '_')) || (i > 0 && (c.is_ascii_alphanumeric() || c == '_')))
        && !matches!(name, "PATH" | "HOME" | "SHELL" | "LD_PRELOAD" | "LD_LIBRARY_PATH")
        && !name.starts_with("LD_")
}

async fn terminal_create_handler(State(state): State<Arc<AppState>>, Json(request): Json<CreateTerminalRequest>) -> Result<Json<TerminalCreated>, (StatusCode, String)> {
    let cwd = workspace_path(request.cwd.as_deref().unwrap_or(WORKSPACE_ROOT), true)?;
    if !cwd.is_dir() { return Err((StatusCode::BAD_REQUEST, "cwd must be a workspace directory".into())); }
    if request.command.is_empty() || request.command.contains('/') || request.args.iter().any(|arg| arg.len() > 32 * 1024) { return Err((StatusCode::BAD_REQUEST, "invalid terminal command".into())); }
    if request.env.iter().any(|value| !safe_env_name(&value.name) || value.value.len() > 32 * 1024) { return Err((StatusCode::BAD_REQUEST, "unsafe terminal environment".into())); }
    let id = Uuid::new_v4().to_string();
    let output_path = PathBuf::from("/tmp").join(format!("pocketcoder-acp-{id}.out"));
    let output = File::create(&output_path).map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "create terminal output".into()))?;
    let output_err = output.try_clone().map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "clone terminal output".into()))?;
    let mut command = tokio::process::Command::new(&request.command);
    command.args(&request.args).current_dir(cwd).env_clear().env("PATH", "/usr/local/bin:/usr/bin:/bin").env("HOME", WORKSPACE_ROOT).stdout(Stdio::from(output)).stderr(Stdio::from(output_err));
    for value in request.env { command.env(value.name, value.value); }
    let mut child = command.spawn().map_err(|_| (StatusCode::BAD_REQUEST, "unable to start terminal command".into()))?;
    let pid = child.id().ok_or((StatusCode::INTERNAL_SERVER_ERROR, "terminal has no pid".into()))?;
    let status = Arc::new(RwLock::new(None));
    let completed = Arc::clone(&status);
    tokio::spawn(async move {
        let result = child.wait().await;
        let exit = match result { Ok(value) => TerminalExit { exit_code: value.code(), signal: None }, Err(_) => TerminalExit { exit_code: None, signal: Some("unknown".into()) } };
        *completed.write() = Some(exit);
    });
    state.terminals.write().insert(id.clone(), Terminal { pid, output_path, output_limit: request.output_byte_limit.unwrap_or(64 * 1024).min(MAX_TERMINAL_OUTPUT_BYTES), status });
    Ok(Json(TerminalCreated { terminal_id: id }))
}

fn terminal_snapshot(terminal: &Terminal) -> TerminalOutput {
    let bytes = fs::read(&terminal.output_path).unwrap_or_default();
    let truncated = bytes.len() > terminal.output_limit;
    let retained = if truncated { &bytes[bytes.len() - terminal.output_limit..] } else { &bytes[..] };
    let output = String::from_utf8_lossy(retained).into_owned();
    TerminalOutput { output, truncated, exit_status: terminal.status.read().clone() }
}

async fn terminal_output_handler(State(state): State<Arc<AppState>>, AxumPath(id): AxumPath<String>) -> Result<Json<TerminalOutput>, (StatusCode, String)> {
    let terminals = state.terminals.read();
    let terminal = terminals.get(&id).ok_or((StatusCode::NOT_FOUND, "terminal not found".into()))?;
    Ok(Json(terminal_snapshot(terminal)))
}

async fn terminal_wait_handler(State(state): State<Arc<AppState>>, AxumPath(id): AxumPath<String>) -> Result<Json<TerminalExit>, (StatusCode, String)> {
    loop {
        let terminal = { state.terminals.read().get(&id).cloned() };
        let Some(terminal) = terminal else { return Err((StatusCode::NOT_FOUND, "terminal not found".into())); };
        if let Some(status) = terminal.status.read().clone() { return Ok(Json(status)); }
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    }
}

async fn terminal_kill_handler(State(state): State<Arc<AppState>>, AxumPath(id): AxumPath<String>) -> Result<StatusCode, (StatusCode, String)> {
    let pid = state.terminals.read().get(&id).ok_or((StatusCode::NOT_FOUND, "terminal not found".into()))?.pid;
    let status = tokio::process::Command::new("kill").args(["-TERM", &pid.to_string()]).status().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "terminate terminal".into()))?;
    if !status.success() { return Err((StatusCode::CONFLICT, "terminal is already finished".into())); }
    Ok(StatusCode::NO_CONTENT)
}

async fn terminal_release_handler(State(state): State<Arc<AppState>>, AxumPath(id): AxumPath<String>) -> Result<StatusCode, (StatusCode, String)> {
    let terminal = state.terminals.write().remove(&id).ok_or((StatusCode::NOT_FOUND, "terminal not found".into()))?;
    let _ = fs::remove_file(terminal.output_path);
    Ok(StatusCode::NO_CONTENT)
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
                terminals: Arc::new(RwLock::new(HashMap::new())),
            });

            let app = Router::new()
                .route("/sse", get(sse_handler))
                .route("/health", get(health_handler))
                .route("/exec", post(exec_handler))
                .route("/acp/fs/read", post(fs_read_handler))
                .route("/acp/fs/write", post(fs_write_handler))
                .route("/acp/terminals", post(terminal_create_handler))
                .route("/acp/terminals/{id}/output", get(terminal_output_handler))
                .route("/acp/terminals/{id}/wait", get(terminal_wait_handler))
                .route("/acp/terminals/{id}", delete(terminal_kill_handler))
                .route("/acp/terminals/{id}/release", post(terminal_release_handler))
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
