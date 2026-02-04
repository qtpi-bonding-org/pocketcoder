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

#[derive(Debug, Deserialize)]
pub struct ExecRequest {
    pub cmd: String,
    pub cwd: Option<String>,
    pub metadata: Option<serde_json::Value>,
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
    async fn create_execution(&self, cmd_id: &str, cwd: &str, status: &str, source: &str, metadata: Option<serde_json::Value>) -> Result<ExecutionRecord>;
    async fn get_execution(&self, id: &str) -> Result<ExecutionRecord>;
    async fn update_execution_status(&self, id: &str, status: &str, output: Option<serde_json::Value>, exit_code: Option<i32>) -> Result<()>;
}

// --------------------------------------------------------------------------
// PocketBase Provider implementation
// --------------------------------------------------------------------------

pub struct PocketBaseProvider {
    url: String,
    admin_token: String,
}

impl PocketBaseProvider {
    pub async fn new(url: String, email: String, pass: String) -> Result<Self> {
        let client = reqwest::Client::new();
        let mut attempts = 0;
        while attempts < 15 {
            let res = client.post(format!("{}/api/collections/users/auth-with-password", url))
                .json(&serde_json::json!({ "identity": email, "password": pass }))
                .send()
                .await;

            match res {
                Ok(resp) if resp.status().is_success() => {
                    let auth: serde_json::Value = resp.json().await?;
                    let token = auth["token"].as_str().ok_or_else(|| anyhow!("PocketBase Auth Failed: No token"))?.to_string();
                    return Ok(Self { url, admin_token: token });
                },
                Ok(resp) => {
                    let err_text = resp.text().await.unwrap_or_default();
                    eprintln!("⚠️ [PocketCoder] Auth failure (Attempt {}): {} - {}", attempts, err_text, url);
                },
                Err(e) => {
                    eprintln!("⚠️ [PocketCoder] Connection failure (Attempt {}): {} at {}", attempts, e, url);
                }
            }
            attempts += 1;
            sleep(Duration::from_secs(2)).await;
        }
        Err(anyhow!("Failed to connect and authenticate with PocketBase Law after multiple attempts."))
    }

    // Helper to make authenticated requests
    async fn request(&self, method: reqwest::Method, endpoint: &str, json: Option<serde_json::Value>) -> Result<reqwest::Response> {
        let client = reqwest::Client::new();
        let mut req = client.request(method, format!("{}{}", self.url, endpoint))
            .header("Authorization", format!("Bearer {}", self.admin_token));
        
        if let Some(body) = json {
            req = req.json(&body);
        }

        let resp = req.send().await?;
        if !resp.status().is_success() {
             let status = resp.status();
             let text = resp.text().await.unwrap_or_default();
             return Err(anyhow!("PocketBase Request Failed [{}]: {}", status, text));
        }
        Ok(resp)
    }
}

#[async_trait]
impl ActionProvider for PocketBaseProvider {
    async fn get_command_by_hash(&self, hash: &str) -> Result<Option<CommandRecord>> {
        // filter=(hash='abc')
        let filter_str = format!("hash='{}'", hash);
        let encoded_filter = urlencoding::encode(&filter_str);
        let resp = self.request(reqwest::Method::GET, &format!("/api/collections/commands/records?filter=({})", encoded_filter), None).await?;
        let json: serde_json::Value = resp.json().await?;
        
        if let Some(items) = json["items"].as_array() {
            if let Some(first) = items.first() {
                let rec: CommandRecord = serde_json::from_value(first.clone())?;
                return Ok(Some(rec));
            }
        }
        Ok(None)
    }

    async fn create_command(&self, cmd: &str, hash: &str) -> Result<CommandRecord> {
        let body = serde_json::json!({ "command": cmd, "hash": hash });
        let resp = self.request(reqwest::Method::POST, "/api/collections/commands/records", Some(body)).await?;
        let rec: CommandRecord = resp.json().await?;
        Ok(rec)
    }

    async fn is_whitelisted(&self, command_id: &str) -> Result<bool> {
        // filter=(command='id' && active=true)
        let filter_str = format!("command='{}' && active=true", command_id);
        let encoded_filter = urlencoding::encode(&filter_str);
        let resp = self.request(reqwest::Method::GET, &format!("/api/collections/whitelists/records?filter=({})", encoded_filter), None).await?;
        let json: serde_json::Value = resp.json().await?;

        if let Some(items) = json["items"].as_array() {
             return Ok(!items.is_empty());
        }
        Ok(false)
    }

    async fn create_execution(&self, cmd_id: &str, cwd: &str, status: &str, source: &str, metadata: Option<serde_json::Value>) -> Result<ExecutionRecord> {
        let mut body = serde_json::json!({
            "command": cmd_id,
            "cwd": cwd,
            "status": status,
            "source": source
        });
        if let Some(meta) = metadata {
            body["metadata"] = meta;
        }

        let resp = self.request(reqwest::Method::POST, "/api/collections/executions/records", Some(body)).await?;
        let rec: ExecutionRecord = resp.json().await?;
        Ok(rec)
    }
    
    async fn get_execution(&self, id: &str) -> Result<ExecutionRecord> {
        let resp = self.request(reqwest::Method::GET, &format!("/api/collections/executions/records/{}", id), None).await?;
        let rec: ExecutionRecord = resp.json().await?;
        Ok(rec)
    }

    async fn update_execution_status(&self, id: &str, status: &str, output: Option<serde_json::Value>, exit_code: Option<i32>) -> Result<()> {
        let mut body = serde_json::json!({ "status": status });
        if let Some(o) = output { body["outputs"] = o; }
        if let Some(e) = exit_code { body["exit_code"] = e.into(); }

        self.request(reqwest::Method::PATCH, &format!("/api/collections/executions/records/{}", id), Some(body)).await?;
        Ok(())
    }
}

// --------------------------------------------------------------------------
// PocketCoder Execution Driver (Shared Socket Sentinel)
// --------------------------------------------------------------------------

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

    pub async fn exec(&self, cmd: &str, cwd: Option<&str>) -> Result<CommandResult> {
        let pane = format!("{}:0.0", self.session_name);
        let sentinel_id = Uuid::new_v4().to_string();
        
        let tmux_args = ["-S", &self.socket_path];
        
        // 1. Sanitize the Pane
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "C-c"]).status();
        
        // Optional: If cwd is provided, try to switch to it first (or ensure we are there).
        // For the 'bridge', the user might be in a subdir.
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
    provider: Arc<dyn ActionProvider>,
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

// The 'message_handler' for JSON-RPC is likely not needed for the Bridge unless we want to keep it backward compatible 
// or for other tools. For this v1, the Bridge uses /exec directly.
// We can keep a stub or minimal version if necessary, but focusing on /exec.

async fn exec_handler(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<ExecRequest>,
) -> Json<serde_json::Value> {
    // 1. Calculate Hash
    let mut hasher = Sha256::new();
    hasher.update(payload.cmd.as_bytes());
    let result = hasher.finalize();
    let hash = hex::encode(result);

    // 2. Get or Create Command
    let cmd_record = match state.provider.get_command_by_hash(&hash).await {
        Ok(Some(rec)) => rec,
        Ok(None) => match state.provider.create_command(&payload.cmd, &hash).await {
            Ok(rec) => rec,
            Err(e) => return Json(serde_json::json!({ "error": format!("Failed to create command record: {}", e) }))
        },
        Err(e) => return Json(serde_json::json!({ "error": format!("Failed to fetch command record: {}", e) }))
    };

    // 3. Check Whitelist
    let whitelisted = state.provider.is_whitelisted(&cmd_record.id).await.unwrap_or(false);
    
    let initial_status = if whitelisted { "authorized" } else { "draft" };
    let cwd = payload.cwd.as_deref().unwrap_or("/workspace");

    // 4. Create Execution
    let exec_record = match state.provider.create_execution(&cmd_record.id, cwd, initial_status, "bridge_v1", payload.metadata.clone()).await {
        Ok(rec) => rec,
        Err(e) => return Json(serde_json::json!({ "error": format!("Failed to create execution record: {}", e) }))
    };

    // 5. Blocking Poll Loop (The Firewall)
    if initial_status == "draft" {
        let start = tokio::time::Instant::now();
        let timeout = Duration::from_secs(300); // 5 min timeout for human approval
        let mut approved = false; 

        println!("🔒 [Firewall] Execution {} is DRAFT. Waiting for sign-off...", exec_record.id);

        while start.elapsed() < timeout {
             // Poll status
             match state.provider.get_execution(&exec_record.id).await {
                 Ok(rec) => {
                     if rec.status == "authorized" {
                         approved = true;
                         break;
                     }
                     if rec.status == "denied" || rec.status == "failed" {
                         return Json(serde_json::json!({ "error": "Execution denied by Gatekeeper." }));
                     }
                 },
                 Err(_) => {} // ignore errors during poll
             }
             sleep(Duration::from_secs(1)).await;
        }

        if !approved {
             // Timeout
             let _ = state.provider.update_execution_status(&exec_record.id, "failed", Some(serde_json::json!({ "error": "Timeout waiting for approval" })), None).await;
             return Json(serde_json::json!({ "error": "Execution timed out waiting for approval." }));
        }
    }

    // 6. Execute!
    // Mark as Executing
    let _ = state.provider.update_execution_status(&exec_record.id, "executing", None, None).await;

    println!("⚡ [Firewall] Executing: {}", payload.cmd);
    match state.driver.exec(&payload.cmd, Some(cwd)).await {
        Ok(res) => {
             let _ = state.provider.update_execution_status(&exec_record.id, "completed", 
                Some(serde_json::json!({ "stdout": res.output })), 
                Some(res.exit_code)
             ).await;
             
             Json(serde_json::json!({
                 "stdout": res.output,
                 "exit_code": res.exit_code
             }))
        },
        Err(e) => {
            let _ = state.provider.update_execution_status(&exec_record.id, "failed", Some(serde_json::json!({ "error": e.to_string() })), None).await;
            Json(serde_json::json!({ "error": e.to_string(), "exit_code": 1 }))
        }
    }
}


// --------------------------------------------------------------------------
// Main
// --------------------------------------------------------------------------

#[tokio::main]
async fn main() -> Result<()> {
    let pb_url = env::var("POCKETBASE_URL").unwrap_or_else(|_| "http://localhost:8090".to_string());
    let admin_email = env::var("ADMIN_EMAIL").expect("ADMIN_EMAIL required");
    let admin_pass = env::var("ADMIN_PASSWORD").expect("ADMIN_PASSWORD required");
    let socket_path = env::var("TMUX_SOCKET").unwrap_or_else(|_| "/tmp/tmux/pocketcoder".to_string());
    let session_name = env::var("TMUX_SESSION").unwrap_or_else(|_| "pocketcoder_session".to_string());

    println!("🏰 [PocketCoder] Gateway starting up...");
    println!("📍 Core: {}", pb_url);
    
    // 2. Initialize the Provider
    let provider = Arc::new(PocketBaseProvider::new(pb_url.clone(), admin_email, admin_pass).await?);

    // 3. Initialize the Execution Driver
    let driver = Arc::new(PocketCoderDriver::new(&socket_path, &session_name));

    let state = Arc::new(AppState {
        provider,
        sessions: Arc::new(RwLock::new(HashMap::new())),
        driver,
    });

    // 4. Setup Router
    let app = Router::new()
        .route("/sse", get(sse_handler))
        .route("/exec", post(exec_handler)) 
        .layer(tower_http::cors::CorsLayer::permissive())
        .with_state(state);

    let port = env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;

    println!("✅ [PocketCoder] Gateway is LIVE on :{}", port);
    axum::serve(listener, app).await?;

    Ok(())
}
