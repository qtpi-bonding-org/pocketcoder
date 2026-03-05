use anyhow::Result;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentProfile {
    pub name: String,
    pub description: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mode: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
}

pub trait CliAgent: Send + Sync {
    fn name(&self) -> &str;
    fn build_run_cmd(
        &self,
        profile: Option<&str>,
        task: &str,
        id: &str,
        agents_dir: &str,
    ) -> String;
    fn build_continue_cmd(
        &self,
        session_id: &str,
        profile: Option<&str>,
        message: &str,
        id: &str,
        turn: u32,
        agents_dir: &str,
    ) -> String;
    fn parse_session_id(&self, log_path: &Path) -> Option<String>;
    fn list_profiles(&self, config_path: &Path) -> Result<Vec<AgentProfile>>;
}

pub struct OpenCodeAgent {
    config_path: std::path::PathBuf,
    session_re: Regex,
}

impl OpenCodeAgent {
    pub fn new(config_path: std::path::PathBuf) -> Self {
        Self {
            config_path,
            session_re: Regex::new(r#""sessionID"\s*:\s*"(ses_[A-Za-z0-9_]+)""#).unwrap(),
        }
    }
}

impl CliAgent for OpenCodeAgent {
    fn name(&self) -> &str {
        "opencode"
    }

    fn build_run_cmd(
        &self,
        profile: Option<&str>,
        task: &str,
        id: &str,
        agents_dir: &str,
    ) -> String {
        let agent_flag = profile
            .map(|p| format!(" --agent {p}"))
            .unwrap_or_default();
        // Escape single quotes in task for shell safety
        let escaped_task = task.replace('\'', "'\\''");
        format!(
            "test -f /llm_keys/llm.env && export $(grep -v '^#' /llm_keys/llm.env | xargs); \
             opencode run{agent_flag} --format json '{escaped_task}' 2>&1 | tee {agents_dir}/{id}.log; \
             echo ${{PIPESTATUS[0]}} > {agents_dir}/{id}.exit"
        )
    }

    fn build_continue_cmd(
        &self,
        session_id: &str,
        profile: Option<&str>,
        message: &str,
        id: &str,
        turn: u32,
        agents_dir: &str,
    ) -> String {
        let agent_flag = profile
            .map(|p| format!(" --agent {p}"))
            .unwrap_or_default();
        let escaped_msg = message.replace('\'', "'\\''");
        format!(
            "test -f /llm_keys/llm.env && export $(grep -v '^#' /llm_keys/llm.env | xargs); \
             opencode run --continue --session {session_id}{agent_flag} --format json '{escaped_msg}' 2>&1 | tee {agents_dir}/{id}-cont-{turn}.log; \
             echo ${{PIPESTATUS[0]}} > {agents_dir}/{id}-cont-{turn}.exit"
        )
    }

    fn parse_session_id(&self, log_path: &Path) -> Option<String> {
        let content = std::fs::read_to_string(log_path).ok()?;
        self.session_re
            .captures(&content)
            .and_then(|caps| caps.get(1).map(|m| m.as_str().to_string()))
    }

    fn list_profiles(&self, config_path: &Path) -> Result<Vec<AgentProfile>> {
        let path = if config_path.as_os_str().is_empty() {
            &self.config_path
        } else {
            config_path
        };
        let content = std::fs::read_to_string(path)?;
        let config: serde_json::Value = serde_json::from_str(&content)?;

        let agents = config
            .get("agent")
            .and_then(|a| a.as_object())
            .map(|obj| {
                obj.iter()
                    .map(|(name, val)| AgentProfile {
                        name: name.clone(),
                        description: val
                            .get("description")
                            .and_then(|d| d.as_str())
                            .unwrap_or("")
                            .to_string(),
                        mode: val.get("mode").and_then(|m| m.as_str()).map(String::from),
                        model: val.get("model").and_then(|m| m.as_str()).map(String::from),
                    })
                    .collect()
            })
            .unwrap_or_default();

        Ok(agents)
    }
}
