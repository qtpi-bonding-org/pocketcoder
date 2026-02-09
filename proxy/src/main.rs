use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::env;
use anyhow::{Result, anyhow};
use std::sync::Arc;
use axum::{
    extract::{State, Query},
    response::sse::{Event, Sse},
    routing::{get, post},
    Json, Router,
};
use futures_util::stream::Stream;
use tokio::sync::mpsc;
use tokio_stream::StreamExt;
use tokio_stream::wrappers::ReceiverStream;
use std::collections::HashMap;
use parking_lot::RwLock;
use tokio::time::{sleep, Duration};
use std::process::Command;
use uuid::Uuid;
use sha2::{Sha256, Digest};
use hex;

// --------------------------------------------------------------------------
// Core Models (Normalized Schema)
// --------------------------------------------------------------------------

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CommandRecord {
    pub id: String,
    pub hash: String,
    pub command: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ExecutionRecord {
    pub id: String,
    pub status: String,
    pub output: Option<serde_json::Value>,
    pub exit_code: Option<i32>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct WhitelistRecord {
    pub id: String,
    pub active: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CommandResult {
    pub output: String,
    pub exit_code: i32,
}

/// ExecRequest represents a shell command execution request.
/// It includes the command string, working directory, and metadata for audit trails.
#[derive(Debug, Deserialize)]
pub struct ExecRequest {
    pub cmd: String,
    pub cwd: Option<String>,
    pub metadata: Option<serde_json::Value>,
    pub usage_id: Option<String>,
    pub session_id: Option<String>,
}

#[async_trait]
pub trait ActionProvider: Send + Sync {
    // Command Logic
    async fn get_command_by_hash(&self, hash: &str) -> Result<Option<CommandRecord>>;
    async fn create_command(&self, cmd: &str, hash: &str) -> Result<CommandRecord>;
    
    // Whitelist Logic
    // Returns true if an active whitelist record exists for this command ID
    async fn is_whitelisted(&self, command_id: &str) -> Result<bool>;
    
    // Execution Logic
    async fn create_execution(&self, cmd_id: &str, cwd: &str, status: &str, source: &str, metadata: Option<serde_json::Value>, usage_id: Option<&str>) -> Result<ExecutionRecord>;
    async fn get_execution(&self, id: &str) -> Result<ExecutionRecord>;
    async fn update_execution_status(&self, id: &str, status: &str, output: Option<serde_json::Value>, exit_code: Option<i32>) -> Result<()>;
}

// --------------------------------------------------------------------------
// PocketCoder Execution Driver (Shared Socket Sentinel)
// --------------------------------------------------------------------------

/// PocketCoderDriver is the core execution engine for the Proxy.
/// It interacts with TMUX via a UNIX socket to run commands in isolated sessions.
/// Each session represents a sandboxed environment for a user or agent.
pub struct PocketCoderDriver {
    socket_path: String,
    session_name: String,
}

impl PocketCoderDriver {
    pub fn new(socket: &str, session: &str) -> Self {
        Self {
            socket_path: socket.to_string(),
            session_name: session.to_string(),
        }
    }

    /// Executes a command within a specific TMUX session, capturing output and exit code.
    ///
    /// The execution flow involves:
    /// 1. Ensuring the target TMUX session exists.
    /// 2. Clearing the session history to ensure a clean capture.
    /// 3. Injecting the command along with a sentinel value to detect completion.
    /// 4. Polling the session output until the sentinel is found or a timeout occurs.
    ///
    /// # Arguments
    /// * `cmd` - The command to execute.
    /// * `cwd` - Optional working directory to execute the command in.
    /// * `session_override` - Optional session name override. If not provided, uses the default session.
    pub async fn exec(&self, cmd: &str, cwd: Option<&str>, session_override: Option<&str>) -> Result<CommandResult> {
        let session = session_override.unwrap_or(&self.session_name);
        
        // Ensure the session exists before executing
        let tmux_args = ["-S", &self.socket_path];
        let status = Command::new("tmux")
            .args(&tmux_args)
            .args(["has-session", "-t", session])
            .status();

        if !status.is_ok() || !status.unwrap().success() {
             println!("🧶 [Proxy] Creating new session: {}", session);
             let _ = Command::new("tmux")
                .args(&tmux_args)
                .args(["new-session", "-d", "-s", session])
                .status();
        }

        let pane = format!("{}:0.0", session);
        let sentinel_id = Uuid::new_v4().to_string();
        
        let tmux_args = ["-S", &self.socket_path];
        
        // 1. Sanitize the Pane
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "C-c"]).status();
        
        // Optional: If cwd is provided, try to switch to it first (or ensure we are there).
        // For the 'relay', the user might be in a subdir.
        // We can just inject "cd <cwd> && <cmd>"
        // But let's keep it simple. We will inject "cd <cwd> 2>/dev/null; <cmd>"
        
        let final_cmd = if let Some(dir) = cwd {
            format!("cd \"{}\" && {}", dir, cmd)
        } else {
             cmd.to_string()
        };

        // Clear history to avoid reading old output
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "clear", "Enter"]).status();
        let _ = Command::new("tmux").args(&tmux_args).args(["clear-history", "-t", &pane]).status();
        
        sleep(Duration::from_millis(300)).await;

        // 2. Inject Command + Exit Code Sentinel
        let wrapped_cmd = format!("{}; echo \"---POCKETCODER_EXIT:$?_ID:{{{}}}---\"", final_cmd, sentinel_id);
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, &wrapped_cmd, "Enter"]).status();

        // 3. Poll for Completion
        let start_time = tokio::time::Instant::now();
        let timeout = Duration::from_secs(300); // 5 minutes execution timeout (matching intent timeout)

        loop {
            if start_time.elapsed() > timeout {
                return Err(anyhow!("Command execution timed out (Sandbox)."));
            }

            let output = Command::new("tmux")
                .args(&tmux_args)
                .args(["capture-pane", "-p", "-t", &pane])
                .output()?;
            
            let content = String::from_utf8_lossy(&output.stdout);
            
            if let Some(pos) = content.find("POCKETCODER_EXIT") {
                if content.contains(&sentinel_id) {
                    let sub = &content[pos..];
                    let exit_code_part = sub.split(':').nth(1).unwrap_or("0").split('_').next().unwrap_or("0");
                    let exit_code = exit_code_part.parse::<i32>().unwrap_or(0);

                    let lines: Vec<&str> = content.lines().collect();
                    let result_output = lines.iter()
                        .filter(|l| !l.contains("POCKETCODER_EXIT"))
                        .map(|s| *s)
                        .collect::<Vec<&str>>()
                        .join("\n")
                        .trim()
                        .to_string();

                    return Ok(CommandResult {
                        output: result_output,
                        exit_code,
                    });
                }
            }
            sleep(Duration::from_millis(200)).await;
        }
    }
}

// --------------------------------------------------------------------------
// SSE Server State
// --------------------------------------------------------------------------

type SessionMap = Arc<RwLock<HashMap<String, mpsc::Sender<serde_json::Value>>>>;

struct AppState {
    sessions: SessionMap,
    driver: Arc<PocketCoderDriver>,
}

#[derive(Deserialize)]
struct SseQuery {
    #[serde(rename = "sessionId")]
    session_id: Option<String>,
}

// --------------------------------------------------------------------------
// Handlers
// --------------------------------------------------------------------------

/// SSE (Server-Sent Events) Handler
/// Establishes a persistent connection for real-time updates.
///
/// # Query Parameters
/// * `sessionId` - Optional session ID. If not provided, a new UUID is generated.
async fn sse_handler(
    State(state): State<Arc<AppState>>,
    Query(query): Query<SseQuery>,
) -> Sse<impl Stream<Item = Result<Event, std::convert::Infallible>>> {
    let session_id = query.session_id.unwrap_or_else(|| Uuid::new_v4().to_string());
    let (tx, rx) = mpsc::channel(100);

    state.sessions.write().insert(session_id.clone(), tx);

    let stream = ReceiverStream::new(rx).map(|msg| {
        Ok(Event::default().data(msg.to_string()).event("message"))
    });

    // println!("🚀 [PocketCoder] New SSE Session: {}", session_id);
    Sse::new(stream)
}

/// Health Check Handler
/// Returns a simple JSON status to indicate the service is running.
async fn health_handler() -> Json<serde_json::Value> {
    Json(serde_json::json!({ "status": "ok" }))
}

/// Execution Handler
/// Accepts a command execution request and forwards it to the TMUX driver.
/// This endpoint assumes that authorization has already been handled by the caller (e.g., Relay).
///
/// # Payload
/// * `cmd` - The command string to execute.
/// * `cwd` - Optional working directory. Defaults to `/workspace`.
/// * `session_id` - Optional session ID for isolating the execution context.
async fn exec_handler(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<ExecRequest>,
) -> Json<serde_json::Value> {
    // The Proxy trusts that commands reaching it are already authorized by the Plugin.
    // No permission checking happens here - we just execute and log results.
    
    let cwd = payload.cwd.as_deref().unwrap_or("/workspace");
    let session_name = payload.session_id.map(|id| format!("pc_{}", id));

    println!("⚡ [Proxy] Executing in session {:?}: {}", session_name, payload.cmd);
    match state.driver.exec(&payload.cmd, Some(cwd), session_name.as_deref()).await {
        Ok(res) => {
             Json(serde_json::json!({
                 "stdout": res.output,
                 "exit_code": res.exit_code
             }))
        },
        Err(e) => {
            Json(serde_json::json!({ "error": e.to_string(), "exit_code": 1 }))
        }
    }
}


// --------------------------------------------------------------------------
// Main
// --------------------------------------------------------------------------

#[tokio::main]
async fn main() -> Result<()> {
    // We no longer need PocketBase credentials. 
    // The Gateway is a dumb execution proxy.
    let socket_path = env::var("TMUX_SOCKET").unwrap_or_else(|_| "/tmp/tmux/pocketcoder".to_string());
    let session_name = env::var("TMUX_SESSION").unwrap_or_else(|_| "pocketcoder_session".to_string());

    println!("🏰 [PocketCoder] Proxy starting up...");
    println!("📍 Mode: Dumb Execution Proxy");
    
    // Initialize the Execution Driver
    let driver = Arc::new(PocketCoderDriver::new(&socket_path, &session_name));

    let state = Arc::new(AppState {
        sessions: Arc::new(RwLock::new(HashMap::new())),
        driver,
    });

    // Setup Router
    let app = Router::new()
        .route("/sse", get(sse_handler))
        .route("/health", get(health_handler))
        .route("/exec", post(exec_handler)) 
        .layer(tower_http::cors::CorsLayer::permissive())
        .with_state(state);

    let port = env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;

    println!("✅ [PocketCoder] Proxy is LIVE on :{}", port);
    axum::serve(listener, app).await?;

    Ok(())
}
