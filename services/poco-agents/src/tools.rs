use crate::agent::CliAgent;
use crate::state::{AgentMeta, AgentState, AgentStatus, AgentStore};
use crate::tmux;
use rmcp::{
    ErrorData as McpError, ServerHandler,
    handler::server::router::tool::ToolRouter,
    handler::server::wrapper::Parameters,
    model::*,
    schemars, tool, tool_handler, tool_router,
};
use serde::Deserialize;
use std::path::Path;
use std::sync::Arc;
use tracing::{info, warn};

// ── Request types ───────────────────────────────────────────────────────────

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct SpawnParams {
    /// Agent profile name (e.g. "poco", "developer"). Defaults to "poco".
    #[serde(default)]
    pub profile: Option<String>,
    /// The task description / prompt for the agent.
    pub task: String,
    /// If true, wait for the agent to complete (poll for .exit file). Default: true.
    #[serde(default = "default_true")]
    pub sync: bool,
    /// Timeout in seconds for sync mode. Default: 600.
    #[serde(default)]
    pub timeout_secs: Option<u64>,
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ContinueAgentParams {
    /// Agent ID to continue.
    pub id: String,
    /// Follow-up message to send to the agent's existing session.
    pub message: String,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct CheckAgentParams {
    /// Agent ID to check.
    pub id: String,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct SnapshotParams {
    /// Agent ID to snapshot.
    pub id: String,
    /// Number of lines to capture. Default: 50.
    #[serde(default)]
    pub lines: Option<u32>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ResultParams {
    /// Agent ID to get result for.
    pub id: String,
    /// Continuation turn number. Omit for latest.
    #[serde(default)]
    pub turn: Option<u32>,
}

#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct CleanupParams {
    /// Agent IDs to clean up.
    pub ids: Vec<String>,
}

// ── Server struct ───────────────────────────────────────────────────────────

#[derive(Clone)]
pub struct PocoAgents {
    store: Arc<AgentStore>,
    cli_agent: Arc<dyn CliAgent>,
    agents_dir: String,
    tmux_socket: String,
    tmux_session: String,
    #[allow(dead_code)]
    tool_router: ToolRouter<Self>,
}

impl PocoAgents {
    pub fn new(
        store: Arc<AgentStore>,
        cli_agent: Arc<dyn CliAgent>,
        agents_dir: String,
        tmux_socket: String,
        tmux_session: String,
    ) -> Self {
        Self {
            store,
            cli_agent,
            agents_dir,
            tmux_socket,
            tmux_session,
            tool_router: Self::tool_router(),
        }
    }

    /// Refresh a single agent's status from filesystem + tmux.
    async fn refresh_agent(&self, id: &str) {
        let state = match self.store.get(id).await {
            Some(s) => s,
            None => return,
        };

        if state.status != AgentStatus::Running {
            return;
        }

        // Check for exit file (base or latest continuation)
        let exit_path = if state.meta.continue_count > 0 {
            Path::new(&self.agents_dir)
                .join(format!("{}-cont-{}.exit", id, state.meta.continue_count))
        } else {
            Path::new(&self.agents_dir).join(format!("{}.exit", id))
        };

        if exit_path.exists() {
            let code = std::fs::read_to_string(&exit_path)
                .ok()
                .and_then(|s| s.trim().parse::<i32>().ok())
                .unwrap_or(-1);
            let status = if code == 0 {
                AgentStatus::Done
            } else {
                AgentStatus::Failed
            };
            self.store.update_status(id, status, Some(code)).await;

            // Try to extract session_id if we don't have one yet
            if state.meta.session_id.is_none() {
                let log_path = Path::new(&self.agents_dir).join(format!("{}.log", id));
                if let Some(sid) = self.cli_agent.parse_session_id(&log_path) {
                    self.store.update_session_id(id, sid).await;
                }
            }
        } else if !tmux::window_exists(&self.tmux_socket, &self.tmux_session, &state.meta.tmux_window) {
            self.store.update_status(id, AgentStatus::Crashed, None).await;
        }
    }
}

fn mcp_err(e: impl std::fmt::Display) -> McpError {
    McpError::internal_error(e.to_string(), None)
}

// ── MCP tool implementations ────────────────────────────────────────────────

#[tool_router]
impl PocoAgents {
    #[tool(
        description = "Spawn a new worker agent. Creates a tmux window and runs `opencode run` with the given task. \
        If sync=true (default), polls for completion up to timeout_secs (default 600). \
        Falls back to async if timeout is reached."
    )]
    async fn spawn(
        &self,
        Parameters(params): Parameters<SpawnParams>,
    ) -> Result<CallToolResult, McpError> {
        let id = uuid::Uuid::new_v4().to_string()[..8].to_string();
        let window_name = format!("agent-{id}");
        let timeout_secs = params.timeout_secs.unwrap_or(600);

        // Create tmux window
        if !tmux::new_window(
            &self.tmux_socket,
            &self.tmux_session,
            &window_name,
            "/workspace",
        ) {
            return Err(mcp_err("failed to create tmux window"));
        }

        // Build and send command
        let cmd = self.cli_agent.build_run_cmd(
            params.profile.as_deref(),
            &params.task,
            &id,
            &self.agents_dir,
        );

        if !tmux::send_keys(&self.tmux_socket, &self.tmux_session, &window_name, &cmd) {
            tmux::kill_window(&self.tmux_socket, &self.tmux_session, &window_name);
            return Err(mcp_err("failed to send command to tmux window"));
        }

        // Write meta
        let meta = AgentMeta {
            id: id.clone(),
            profile: params.profile.clone(),
            session_id: None,
            created: chrono::Utc::now().to_rfc3339(),
            tmux_window: window_name,
            continue_count: 0,
        };
        AgentStore::write_meta(&self.agents_dir, &meta).map_err(mcp_err)?;

        // Insert into store
        let state = AgentState {
            meta,
            status: AgentStatus::Running,
            exit_code: None,
        };
        self.store.insert(state).await;

        info!("spawned agent {id} with profile {:?}", params.profile);

        if params.sync {
            // Poll for exit file
            let exit_path = Path::new(&self.agents_dir).join(format!("{id}.exit"));
            let deadline = tokio::time::Instant::now() + tokio::time::Duration::from_secs(timeout_secs);

            loop {
                if exit_path.exists() {
                    self.refresh_agent(&id).await;
                    let state = self.store.get(&id).await.ok_or_else(|| {
                        mcp_err(format!("agent {id} disappeared from store mid-poll"))
                    })?;

                    // Read log
                    let log_path = Path::new(&self.agents_dir).join(format!("{id}.log"));
                    let log = std::fs::read_to_string(&log_path).unwrap_or_default();

                    return Ok(CallToolResult::success(vec![Content::text(
                        serde_json::to_string_pretty(&serde_json::json!({
                            "id": id,
                            "status": state.status,
                            "exit_code": state.exit_code,
                            "output": log,
                        }))
                        .expect("failed to serialize spawn result"),
                    )]));
                }

                if tokio::time::Instant::now() >= deadline {
                    info!("agent {id} timed out after {timeout_secs}s, returning async");
                    return Ok(CallToolResult::success(vec![Content::text(
                        serde_json::to_string_pretty(&serde_json::json!({
                            "id": id,
                            "status": "running",
                            "message": format!("Agent still running after {timeout_secs}s. Use check_agent or result to poll.")
                        }))
                        .expect("failed to serialize timeout response"),
                    )]));
                }

                tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
            }
        }

        Ok(CallToolResult::success(vec![Content::text(
            serde_json::to_string_pretty(&serde_json::json!({
                "id": id,
                "status": "running",
                "message": "Agent spawned. Use check_agent to poll status."
            }))
            .expect("failed to serialize spawn response"),
        )]))
    }

    #[tool(
        description = "Continue an existing agent session with a follow-up message. \
        Sends a new `opencode run --continue` command in the same tmux window."
    )]
    async fn continue_agent(
        &self,
        Parameters(params): Parameters<ContinueAgentParams>,
    ) -> Result<CallToolResult, McpError> {
        let state = self.store.get(&params.id).await.ok_or_else(|| {
            mcp_err(format!("agent {} not found", params.id))
        })?;

        let session_id = state.meta.session_id.clone().or_else(|| {
            // Try to parse from log
            let log_path = Path::new(&self.agents_dir).join(format!("{}.log", params.id));
            self.cli_agent.parse_session_id(&log_path)
        });

        let session_id = session_id.ok_or_else(|| {
            mcp_err(format!(
                "no session_id found for agent {}. Agent may not have completed initial run.",
                params.id
            ))
        })?;

        // Update session_id if we just parsed it
        if state.meta.session_id.is_none() {
            self.store
                .update_session_id(&params.id, session_id.clone())
                .await;
        }

        let turn = self
            .store
            .increment_continue(&params.id)
            .await
            .ok_or_else(|| mcp_err("agent not found"))?;

        let cmd = self.cli_agent.build_continue_cmd(
            &session_id,
            state.meta.profile.as_deref(),
            &params.message,
            &params.id,
            turn,
            &self.agents_dir,
        );

        // Mark as running again
        self.store
            .update_status(&params.id, AgentStatus::Running, None)
            .await;

        if !tmux::send_keys(
            &self.tmux_socket,
            &self.tmux_session,
            &state.meta.tmux_window,
            &cmd,
        ) {
            return Err(mcp_err("failed to send continue command to tmux window"));
        }

        // Update meta on disk
        if let Some(updated) = self.store.get(&params.id).await {
            let _ = AgentStore::write_meta(&self.agents_dir, &updated.meta);
        }

        info!("continued agent {} (turn {turn})", params.id);

        Ok(CallToolResult::success(vec![Content::text(
            serde_json::to_string_pretty(&serde_json::json!({
                "id": params.id,
                "session_id": session_id,
                "turn": turn,
                "status": "running"
            }))
            .expect("failed to serialize continue response"),
        )]))
    }

    #[tool(description = "List all tracked agents with their current status.")]
    async fn list_agents(&self) -> Result<CallToolResult, McpError> {
        // Refresh all running agents
        let agents = self.store.list().await;
        for a in &agents {
            if a.status == AgentStatus::Running {
                self.refresh_agent(&a.meta.id).await;
            }
        }

        let agents = self.store.list().await;
        let list: Vec<serde_json::Value> = agents
            .iter()
            .map(|a| {
                serde_json::json!({
                    "id": a.meta.id,
                    "profile": a.meta.profile,
                    "status": a.status,
                    "exit_code": a.exit_code,
                    "created": a.meta.created,
                    "continue_count": a.meta.continue_count,
                })
            })
            .collect();

        Ok(CallToolResult::success(vec![Content::text(
            serde_json::to_string_pretty(&list).expect("failed to serialize agent list"),
        )]))
    }

    #[tool(description = "Check a single agent's status. Refreshes from filesystem and tmux.")]
    async fn check_agent(
        &self,
        Parameters(params): Parameters<CheckAgentParams>,
    ) -> Result<CallToolResult, McpError> {
        self.refresh_agent(&params.id).await;

        let state = self.store.get(&params.id).await.ok_or_else(|| {
            mcp_err(format!("agent {} not found", params.id))
        })?;

        Ok(CallToolResult::success(vec![Content::text(
            serde_json::to_string_pretty(&serde_json::json!({
                "id": state.meta.id,
                "profile": state.meta.profile,
                "status": state.status,
                "exit_code": state.exit_code,
                "session_id": state.meta.session_id,
                "created": state.meta.created,
                "continue_count": state.meta.continue_count,
            }))
            .expect("failed to serialize agent status"),
        )]))
    }

    #[tool(description = "Capture the visible tmux pane content for an agent (live terminal snapshot).")]
    async fn snapshot(
        &self,
        Parameters(params): Parameters<SnapshotParams>,
    ) -> Result<CallToolResult, McpError> {
        let state = self.store.get(&params.id).await.ok_or_else(|| {
            mcp_err(format!("agent {} not found", params.id))
        })?;

        let lines = params.lines.unwrap_or(50);
        let content = tmux::capture_pane(
            &self.tmux_socket,
            &self.tmux_session,
            &state.meta.tmux_window,
            lines,
        )
        .ok_or_else(|| mcp_err("failed to capture pane content"))?;

        Ok(CallToolResult::success(vec![Content::text(content)]))
    }

    #[tool(description = "Read the log file output for an agent. Omit turn for latest log.")]
    async fn result(
        &self,
        Parameters(params): Parameters<ResultParams>,
    ) -> Result<CallToolResult, McpError> {
        let state = self.store.get(&params.id).await.ok_or_else(|| {
            mcp_err(format!("agent {} not found", params.id))
        })?;

        let log_path = match params.turn {
            Some(t) => {
                Path::new(&self.agents_dir).join(format!("{}-cont-{t}.log", params.id))
            }
            None => {
                // Find latest: check continuation logs in reverse, fall back to base
                let mut latest = Path::new(&self.agents_dir).join(format!("{}.log", params.id));
                for t in (1..=state.meta.continue_count).rev() {
                    let cont_path = Path::new(&self.agents_dir)
                        .join(format!("{}-cont-{t}.log", params.id));
                    if cont_path.exists() {
                        latest = cont_path;
                        break;
                    }
                }
                latest
            }
        };

        let content = std::fs::read_to_string(&log_path).map_err(|e| {
            mcp_err(format!("failed to read log {:?}: {e}", log_path))
        })?;

        Ok(CallToolResult::success(vec![Content::text(content)]))
    }

    #[tool(description = "List available agent profiles from the OpenCode config.")]
    async fn profiles(&self) -> Result<CallToolResult, McpError> {
        let profiles = self
            .cli_agent
            .list_profiles(Path::new(""))
            .map_err(mcp_err)?;

        Ok(CallToolResult::success(vec![Content::text(
            serde_json::to_string_pretty(&profiles).expect("failed to serialize profiles"),
        )]))
    }

    #[tool(description = "Clean up finished agents. Kills tmux windows and removes log/meta/exit files.")]
    async fn cleanup(
        &self,
        Parameters(params): Parameters<CleanupParams>,
    ) -> Result<CallToolResult, McpError> {
        let mut cleaned = Vec::new();
        let mut errors = Vec::new();

        for id in &params.ids {
            if let Some(state) = self.store.remove(id).await {
                // Kill tmux window if it exists
                tmux::kill_window(&self.tmux_socket, &self.tmux_session, &state.meta.tmux_window);

                // Remove files
                let dir = Path::new(&self.agents_dir);
                for suffix in &["log", "exit", "meta"] {
                    let _ = std::fs::remove_file(dir.join(format!("{id}.{suffix}")));
                }
                // Remove continuation files
                for t in 1..=state.meta.continue_count {
                    let _ = std::fs::remove_file(dir.join(format!("{id}-cont-{t}.log")));
                    let _ = std::fs::remove_file(dir.join(format!("{id}-cont-{t}.exit")));
                }

                cleaned.push(id.clone());
                info!("cleaned up agent {id}");
            } else {
                warn!("agent {id} not found for cleanup");
                errors.push(format!("{id}: not found"));
            }
        }

        Ok(CallToolResult::success(vec![Content::text(
            serde_json::to_string_pretty(&serde_json::json!({
                "cleaned": cleaned,
                "errors": errors,
            }))
            .expect("failed to serialize cleanup result"),
        )]))
    }
}

// ── ServerHandler implementation ────────────────────────────────────────────

#[tool_handler]
impl ServerHandler for PocoAgents {
    fn get_info(&self) -> ServerInfo {
        ServerInfo::new(
            ServerCapabilities::builder()
                .enable_tools()
                .build(),
        )
        .with_server_info(Implementation::new(
            "poco-agents",
            env!("CARGO_PKG_VERSION"),
        ))
        .with_protocol_version(ProtocolVersion::V_2025_03_26)
        .with_instructions(
            "Agent orchestration for PocketCoder. Use spawn to create worker agents, \
             continue_agent to send follow-up messages, list_agents/check_agent to monitor, \
             snapshot for live terminal output, result for log files, profiles to list \
             available agent configurations, and cleanup to remove finished agents.",
        )
    }
}
