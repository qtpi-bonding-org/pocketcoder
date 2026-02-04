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

// --------------------------------------------------------------------------
// Core Models
// --------------------------------------------------------------------------

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Intent {
    pub id: String,
    pub status: String,
    pub message: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CommandResult {
    pub output: String,
    pub exit_code: i32,
}

#[async_trait]
pub trait IntentProvider: Send + Sync {
    async fn get_intent(&self, id: &str) -> Result<Intent>;
    async fn update_intent_status(&self, id: &str, status: &str, output: Option<serde_json::Value>) -> Result<()>;
}

// --------------------------------------------------------------------------
// PocketBase Provider
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
}

#[async_trait]
impl IntentProvider for PocketBaseProvider {
    async fn get_intent(&self, id: &str) -> Result<Intent> {
        let client = reqwest::Client::new();
        let res = client.get(format!("{}/api/collections/intents/records/{}", self.url, id))
            .header("Authorization", format!("Bearer {}", self.admin_token))
            .send()
            .await?;
        let data: Intent = res.json().await?;
        Ok(data)
    }

    async fn update_intent_status(&self, id: &str, status: &str, output: Option<serde_json::Value>) -> Result<()> {
        let client = reqwest::Client::new();
        let mut body = serde_json::json!({ "status": status });
        if let Some(out) = output { body["output"] = out; }
        client.patch(format!("{}/api/collections/intents/records/{}", self.url, id))
            .header("Authorization", format!("Bearer {}", self.admin_token))
            .json(&body)
            .send()
            .await?;
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

    pub async fn exec(&self, cmd: &str) -> Result<CommandResult> {
        let pane = format!("{}:0.0", self.session_name);
        let sentinel_id = Uuid::new_v4().to_string();
        
        // 🛡️ [SOVEREIGN] Use the shared socket to talk directly to the sandbox tmux
        let tmux_args = ["-S", &self.socket_path];
        
        // 1. Sanitize the Pane
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "C-c"]).status();
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "clear", "Enter"]).status();
        let _ = Command::new("tmux").args(&tmux_args).args(["clear-history", "-t", &pane]).status();
        
        sleep(Duration::from_millis(300)).await; // Settle time

        // 2. Inject Command + Exit Code Sentinel
        // We use POCKETCODER_EXIT as requested.
        let wrapped_cmd = format!("{}; echo \"---POCKETCODER_EXIT:$?_ID:{{{}}}---\"", cmd, sentinel_id);
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, &wrapped_cmd, "Enter"]).status();

        // 3. Poll for Completion
        let start_time = tokio::time::Instant::now();
        let timeout = Duration::from_secs(60);

        loop {
            if start_time.elapsed() > timeout {
                return Err(anyhow!("Command timed out after 60 seconds."));
            }

            let output = Command::new("tmux")
                .args(&tmux_args)
                .args(["capture-pane", "-p", "-t", &pane])
                .output()?;
            
            let content = String::from_utf8_lossy(&output.stdout);
            
            if let Some(pos) = content.find("POCKETCODER_EXIT") {
                if content.contains(&sentinel_id) {
                    // Extract Exit Code and Output
                    // Example Line: ---POCKETCODER_EXIT:0_ID:{...}---
                    let sub = &content[pos..];
                    let exit_code_part = sub.split(':').nth(1).unwrap_or("0").split('_').next().unwrap_or("0");
                    let exit_code = exit_code_part.parse::<i32>().unwrap_or(0);

                    // Output is everything before the sentinel line
                    let lines: Vec<&str> = content.lines().collect();
                    // Filter out the POCKETCODER_EXIT line and the echo command if it's visible
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
    provider: Arc<dyn IntentProvider>,
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

    println!("🚀 [PocketCoder] New SSE Session: {}", session_id);
    Sse::new(stream)
}

async fn message_handler(
    State(state): State<Arc<AppState>>,
    Query(query): Query<SseQuery>,
    Json(payload): Json<serde_json::Value>,
) -> Json<serde_json::Value> {
    let method = payload["method"].as_str().unwrap_or("");
    let id = payload["id"].clone();

    match method {
        "initialize" => {
            Json(serde_json::json!({
                "jsonrpc": "2.0",
                "id": id,
                "result": {
                    "capabilities": { "tools": {} },
                    "serverInfo": { "name": "pocketcoder-gateway", "version": "0.1.0" }
                }
            }))
        },
        "tools/list" => {
            Json(serde_json::json!({
                "jsonrpc": "2.0",
                "id": id,
                "result": {
                    "tools": [
                        {
                            "name": "terminal_run",
                            "description": "Execute a terminal command in the secure sandbox.",
                            "inputSchema": {
                                "type": "object",
                                "properties": {
                                    "intent_id": { "type": "string" },
                                    "command": { "type": "string" }
                                },
                                "required": ["intent_id", "command"]
                            }
                        }
                    ]
                }
            }))
        },
        "tools/call" => {
            let result = handle_call_tool(&payload, &*state.provider, &*state.driver).await;
            match result {
                Ok(res) => Json(res),
                Err(e) => {
                    eprintln!("❌ [PocketCoder] Tool call failed: {}", e);
                    Json(serde_json::json!({
                        "jsonrpc": "2.0",
                        "id": id,
                        "error": { "code": -32000, "message": e.to_string() }
                    }))
                }
            }
        },
        _ => Json(serde_json::json!({ "jsonrpc": "2.0", "id": id, "result": {} }))
    }
}

async fn handle_call_tool(req: &serde_json::Value, provider: &dyn IntentProvider, driver: &PocketCoderDriver) -> Result<serde_json::Value> {
    let tool_name = req["params"]["name"].as_str().ok_or_else(|| anyhow!("No tool name"))?;
    let id = req["id"].clone();
    
    if tool_name == "terminal_run" {
        let args = &req["params"]["arguments"];
        let intent_id = args["intent_id"].as_str().ok_or_else(|| anyhow!("No intent_id"))?;
        let command = args["command"].as_str().ok_or_else(|| anyhow!("No command"))?;

        // 🛡️ SOVEREIGN GATE CHECK
        let intent = provider.get_intent(intent_id).await?;
        if intent.status != "authorized" { 
            return Err(anyhow!("🛡️ Authorization Required: Intent {} is NOT authorized.", intent_id)); 
        }
        if intent.message != command { 
            return Err(anyhow!("🚫 Anti-Tamper: Command mismatch for Intent {}.", intent_id)); 
        }

        provider.update_intent_status(intent_id, "executing", None).await?;
        
        // 🔨 EXECUTION (Direct Shared Socket Driver)
        println!("🔨 [PocketCoder] Executing in Sandbox: {}", command);
        match driver.exec(command).await {
            Ok(res) => {
                provider.update_intent_status(intent_id, "completed", Some(serde_json::json!({ 
                    "stdout": res.output,
                    "exit_code": res.exit_code
                }))).await?;

                return Ok(serde_json::json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": { "content": [ { "type": "text", "text": res.output } ] }
                }));
            },
            Err(e) => {
                provider.update_intent_status(intent_id, "failed", Some(serde_json::json!({ "error": e.to_string() }))).await?;
                return Err(anyhow!("Execution failed: {}", e));
            }
        }
    }
    Ok(serde_json::json!({ "jsonrpc": "2.0", "id": id, "result": {} }))
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
    println!("🔌 Socket: {}", socket_path);
    
    // 2. Initialize the Provider with automatic retry
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
        .route("/message", post(message_handler))
        .layer(tower_http::cors::CorsLayer::permissive())
        .with_state(state);

    let port = env::var("PORT").unwrap_or_else(|_| "3001".to_string());
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;

    println!("✅ [PocketCoder] Gateway is LIVE on :{}", port);
    axum::serve(listener, app).await?;

    Ok(())
}
