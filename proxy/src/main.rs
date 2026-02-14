/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
*/

mod driver;
mod shell;
mod mcp_proxy;
mod mcp_stdio_client;

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
    routing::{get, post, any},
    Json, Router,
};
use futures_util::stream::Stream;
use tokio_stream::StreamExt;
use tokio_stream::wrappers::ReceiverStream;

use crate::driver::{PocketCoderDriver, ExecRequest, NotifyRequest};
use crate::mcp_proxy::{mcp_ws_handler, McpQuery};

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
    /// Run in MCP bridge mode (stdio -> proxy bridge)
    Mcp {
        #[arg(short, long)]
        session_id: Option<String>,
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

async fn health_handler() -> &'static str {
    "ok"
}

async fn sse_handler(
    State(state): State<Arc<AppState>>,
    Query(query): Query<McpQuery>,
) -> Sse<impl Stream<Item = Result<Event, std::convert::Infallible>>> {
    let session_id = query.session_id.unwrap_or_else(|| Uuid::new_v4().to_string());
    println!("📡 [Server/SSE] New session: {}", session_id);
    let (tx, rx) = mpsc::channel(100);

    state.sessions.write().insert(session_id.clone(), tx);

    let stream = ReceiverStream::new(rx).map(|msg| {
        Ok(Event::default().data(msg.to_string()).event("message"))
    });

    Sse::new(stream)
}

async fn exec_handler(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<ExecRequest>,
) -> Json<serde_json::Value> {
    let cwd = if payload.cwd.is_empty() { "/workspace" } else { &payload.cwd };
    let session_name = payload.session_id.as_deref();

    println!("⚡ [Server/Exec] Cmd: {}", payload.cmd);
    match state.driver.exec(&payload.cmd, Some(cwd), session_name.as_deref()).await {
        Ok(res) => Json(serde_json::json!({ "stdout": res.output, "exit_code": res.exit_code })),
        Err(e) => Json(serde_json::json!({ "error": e.to_string(), "exit_code": 1 })),
    }
}

async fn mcp_sse_relay_handler(
    method: axum::http::Method,
    uri: axum::http::Uri,
    headers: axum::http::HeaderMap,
    body: axum::body::Bytes,
) -> impl axum::response::IntoResponse {
    let client = reqwest::Client::new();
    let path_query = uri.path_and_query().map(|pq| pq.as_str()).unwrap_or("");
    // Forward /mcp/... to sandbox:9888/...
    // Also strip "ses_" prefix from session_id if OpenCode added it
    let target_path = path_query.replace("/mcp", "").replace("session_id=ses_", "session_id=");
    let sandbox_url = format!("http://sandbox:9888{}", target_path);

    println!("📡 [Proxy/MCP] Incoming: {} {}", method, uri);
    println!("📡 [Proxy/MCP] Relaying to Sandbox: {}", sandbox_url);

    let req_method = reqwest::Method::from_bytes(method.as_str().as_bytes()).unwrap_or(reqwest::Method::GET);
    let mut req_builder = client.request(req_method, sandbox_url).body(body);
    for (key, value) in headers.iter() {
        if key.as_str().to_lowercase() != "host" {
            // println!("   Header: {}: {:?}", key, value);
            req_builder = req_builder.header(key.clone(), value.clone());
        }
    }

    match req_builder.send().await {
        Ok(res) => {
            let status_code = res.status().as_u16();
            println!("✅ [Proxy/MCP] Sandbox responded: {}", status_code);
            let status = axum::http::StatusCode::from_u16(status_code).unwrap_or(axum::http::StatusCode::INTERNAL_SERVER_ERROR);
            let mut res_headers = axum::http::HeaderMap::new();
            for (key, value) in res.headers().iter() {
                res_headers.insert(key.clone(), value.clone());
            }
            // STREAM the body, do not await bytes()!
            // We need to rewrite the endpoint URL on the fly.
            // Since the endpoint event is sent at the start, a simple replace on chunks works 99% of the time,
            // assuming the URL doesn't split across chunk boundaries (unlikely for the first packet).
            let stream = res.bytes_stream().map(|result| {
                result.map(|bytes| {
                    let s = String::from_utf8_lossy(&bytes);
                    // 1. Rewrite relative paths to absolute proxy paths
                    // 2. Prefix session_id with "ses_" for OpenCode validation
                    let replaced = s.replace("data: /", "data: http://proxy:3001/mcp/")
                                    .replace("session_id=", "session_id=ses_");
                    axum::body::Bytes::from(replaced.into_bytes())
                })
            });
            
            let body = axum::body::Body::from_stream(stream);
            (status, res_headers, body).into_response()
        }
        Err(e) => {
            println!("❌ [Proxy/MCP] Sandbox request failed: {}", e);
            (axum::http::StatusCode::BAD_GATEWAY, e.to_string()).into_response()
        }
    }
}

async fn notify_handler(
    State(_state): State<Arc<AppState>>,
    Json(payload): Json<NotifyRequest>,
) -> Json<serde_json::Value> {
    println!("🔔 [Server/Notify] Session: {}, Event: {}", payload.session_id, payload.event_type);
    
    let client = reqwest::Client::new();
    let opencode_url = env::var("OPENCODE_URL").unwrap_or_else(|_| "http://opencode:3000".to_string());
    
    let nudge_message = payload.payload.get("output")
        .and_then(|o| o.as_str())
        .unwrap_or("Task completed.");

    let body = serde_json::json!({
        "role": "user",
        "parts": [{"type": "text", "text": format!("**[Reflex Arc]** Worker task completed:\n\n{}", nudge_message)}]
    });

    // OPENCODE REQUIRES session IDs to start with "ses_"
    let display_session_id = if payload.session_id.starts_with("ses_") {
        payload.session_id.clone()
    } else {
        format!("ses_{}", payload.session_id)
    };

    match client.post(format!("{}/session/{}/prompt_async", opencode_url, display_session_id))
        .json(&body)
        .send()
        .await {
            Ok(_) => {
                println!("✅ [Server/Notify] Brain nudged");
                Json(serde_json::json!({ "status": "ok" }))
            },
            Err(e) => {
                println!("⚠️ [Server/Notify] Nudge failed: {}", e);
                Json(serde_json::json!({ "error": e.to_string() }))
            }
        }
}

/// Legacy CAO Proxy (9889)
async fn legacy_proxy_handler(
    method: axum::http::Method,
    uri: axum::http::Uri,
    headers: axum::http::HeaderMap,
    body: axum::body::Bytes,
) -> impl axum::response::IntoResponse {
    let client = reqwest::Client::new();
    let path_query = uri.path_and_query().map(|pq| pq.as_str()).unwrap_or("");
    let sandbox_url = format!("http://sandbox:9889{}", path_query);

    let req_method = reqwest::Method::from_bytes(method.as_str().as_bytes()).unwrap_or(reqwest::Method::GET);
    let mut req_builder = client.request(req_method, sandbox_url).body(body);
    for (key, value) in headers.iter() {
        if key.as_str().to_lowercase() != "host" {
            req_builder = req_builder.header(key.clone(), value.clone());
        }
    }

    match req_builder.send().await {
        Ok(res) => {
            let status = axum::http::StatusCode::from_u16(res.status().as_u16()).unwrap_or(axum::http::StatusCode::INTERNAL_SERVER_ERROR);
            let mut res_headers = axum::http::HeaderMap::new();
            for (key, value) in res.headers().iter() {
                res_headers.insert(key.clone(), value.clone());
            }
            let bytes = res.bytes().await.unwrap_or_default();
            (status, res_headers, bytes).into_response()
        }
        Err(e) => (axum::http::StatusCode::BAD_GATEWAY, e.to_string()).into_response()
    }
}

// --------------------------------------------------------------------------
// Entry Point
// --------------------------------------------------------------------------

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Server { port } => {
            let socket_path = env::var("TMUX_SOCKET").unwrap_or_else(|_| "/tmp/tmux/pocketcoder".to_string());
            let session_name = env::var("TMUX_SESSION").unwrap_or_else(|_| "pocketcoder_session".to_string());

            println!("🏰 [PocketCoder] Mode: SERVER (Port: {})", port);
            
            let driver = Arc::new(PocketCoderDriver::new(&socket_path, &session_name));
            let state = Arc::new(AppState {
                sessions: Arc::new(RwLock::new(HashMap::new())),
                driver,
            });

            let app = Router::new()
                .route("/sse", get(sse_handler))
                .route("/health", get(health_handler))
                .route("/exec", post(exec_handler)) 
                .route("/notify", post(notify_handler))
                .route("/mcp/ws", get(mcp_ws_handler))
                .route("/mcp/*path", any(mcp_sse_relay_handler))
                .route("/messages/*path", any(mcp_sse_relay_handler))
                .layer(tower_http::cors::CorsLayer::permissive())
                .with_state(state);

            let legacy_app = Router::new()
                .fallback(legacy_proxy_handler)
                .layer(tower_http::cors::CorsLayer::permissive());

            println!("🚀 [PocketCoder] Server components ready");
            
            let addr = format!("0.0.0.0:{}", port);
            let legacy_addr = "0.0.0.0:9889";

            println!("✅ [PocketCoder] Main Gateway: {}", addr);
            println!("✅ [PocketCoder] Legacy Relay: {}", legacy_addr);

            let listener = tokio::net::TcpListener::bind(addr).await?;
            let legacy_listener = tokio::net::TcpListener::bind(legacy_addr).await?;

            tokio::select! {
                res = axum::serve(listener, app) => res?,
                res = axum::serve(legacy_listener, legacy_app) => res?,
            }
        },
        Commands::Shell { command, args } => {
            shell::run(command, args)?;
        }
        Commands::Mcp { session_id } => {
            mcp_stdio_client::run(session_id).await?;
        }
    }

    Ok(())
}
