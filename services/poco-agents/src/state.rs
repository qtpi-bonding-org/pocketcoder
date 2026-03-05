use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;
use tokio::sync::RwLock;
use tracing::{info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentMeta {
    pub id: String,
    pub profile: Option<String>,
    pub session_id: Option<String>,
    pub created: String,
    pub tmux_window: String,
    #[serde(default)]
    pub continue_count: u32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum AgentStatus {
    Running,
    Done,
    Failed,
    Crashed,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentState {
    pub meta: AgentMeta,
    pub status: AgentStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub exit_code: Option<i32>,
}

pub struct AgentStore {
    agents: RwLock<HashMap<String, AgentState>>,
}

impl AgentStore {
    pub async fn recover(agents_dir: &str, tmux_socket: &str, tmux_session: &str) -> Self {
        let mut map = HashMap::new();
        let dir = Path::new(agents_dir);

        if let Ok(entries) = std::fs::read_dir(dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) != Some("meta") {
                    continue;
                }

                let content = match std::fs::read_to_string(&path) {
                    Ok(c) => c,
                    Err(e) => {
                        warn!("failed to read meta file {:?}: {e}", path);
                        continue;
                    }
                };

                let meta: AgentMeta = match serde_json::from_str(&content) {
                    Ok(m) => m,
                    Err(e) => {
                        warn!("failed to parse meta file {:?}: {e}", path);
                        continue;
                    }
                };

                let id = meta.id.clone();

                // Determine status from exit file and tmux
                let exit_path = dir.join(format!("{}.exit", id));
                let (status, exit_code) = if exit_path.exists() {
                    let code = std::fs::read_to_string(&exit_path)
                        .ok()
                        .and_then(|s| s.trim().parse::<i32>().ok())
                        .unwrap_or(-1);
                    if code == 0 {
                        (AgentStatus::Done, Some(code))
                    } else {
                        (AgentStatus::Failed, Some(code))
                    }
                } else if crate::tmux::window_exists(tmux_socket, tmux_session, &meta.tmux_window)
                {
                    (AgentStatus::Running, None)
                } else {
                    (AgentStatus::Crashed, None)
                };

                info!("recovered agent {id}: {status:?}");
                map.insert(
                    id,
                    AgentState {
                        meta,
                        status,
                        exit_code,
                    },
                );
            }
        }

        Self {
            agents: RwLock::new(map),
        }
    }

    pub async fn insert(&self, state: AgentState) {
        let id = state.meta.id.clone();
        self.agents.write().await.insert(id, state);
    }

    pub async fn get(&self, id: &str) -> Option<AgentState> {
        self.agents.read().await.get(id).cloned()
    }

    pub async fn list(&self) -> Vec<AgentState> {
        self.agents.read().await.values().cloned().collect()
    }

    pub async fn remove(&self, id: &str) -> Option<AgentState> {
        self.agents.write().await.remove(id)
    }

    pub async fn update_status(&self, id: &str, status: AgentStatus, exit_code: Option<i32>) {
        if let Some(state) = self.agents.write().await.get_mut(id) {
            state.status = status;
            state.exit_code = exit_code;
        }
    }

    pub async fn update_session_id(&self, id: &str, session_id: String) {
        if let Some(state) = self.agents.write().await.get_mut(id) {
            state.meta.session_id = Some(session_id);
        }
    }

    pub async fn increment_continue(&self, id: &str) -> Option<u32> {
        if let Some(state) = self.agents.write().await.get_mut(id) {
            state.meta.continue_count += 1;
            Some(state.meta.continue_count)
        } else {
            None
        }
    }

    pub async fn len(&self) -> usize {
        self.agents.read().await.len()
    }

    pub fn write_meta(agents_dir: &str, meta: &AgentMeta) -> anyhow::Result<()> {
        let path = Path::new(agents_dir).join(format!("{}.meta", meta.id));
        let json = serde_json::to_string_pretty(meta)?;
        std::fs::write(path, json)?;
        Ok(())
    }
}
