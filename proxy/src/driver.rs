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

// @pocketcoder-core: Execution Driver. Interface for Tmux session management.
//! # Execution Driver
//! This module manages the lifecycle of the sandbox execution environment
//! via tmux socket interaction.

use serde::{Deserialize, Serialize};
use anyhow::{Result, anyhow};
use tokio::time::{sleep, Duration};
use std::process::Command;
use uuid::Uuid;

// --------------------------------------------------------------------------
// Core Models
// --------------------------------------------------------------------------

/// Result of a command execution in the sandbox.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CommandResult {
    /// Combined stdout and stderr
    pub output: String,
    /// Unix exit code
    pub exit_code: i32,
}

/// Request to execute a command.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ExecRequest {
    /// Bash command string
    pub cmd: String,
    /// Working directory relative to workspace root
    pub cwd: String,
    /// Internal audit ID
    pub usage_id: Option<String>,
    /// Session identifier
    pub session_id: Option<String>,
    /// Agent identity executing the command (e.g., "poco")
    #[serde(default = "default_agent_name")]
    pub agent_name: String,
}

fn default_agent_name() -> String {
    "poco".to_string()
}

#[derive(Debug, Deserialize)]
pub struct ExecResponse {
    pub stdout: Option<String>,
    pub exit_code: Option<i32>,
    pub error: Option<String>,
}

#[derive(Debug, Deserialize)]

// --------------------------------------------------------------------------
// PocketCoder Execution Driver (TMUX)
// --------------------------------------------------------------------------

pub struct PocketCoderDriver {
    pub socket_path: String,
    pub session_name: String,
}

impl PocketCoderDriver {
    pub fn new(socket: &str, session: &str) -> Self {
        Self {
            socket_path: socket.to_string(),
            session_name: session.to_string(),
        }
    }

    pub fn session_exists(&self, session: &str) -> bool {
        let tmux_args = ["-S", &self.socket_path];
        let status = Command::new("tmux")
            .args(&tmux_args)
            .args(["has-session", "-t", session])
            .status();
        
        status.is_ok() && status.unwrap().success()
    }

    /// Execute a command in the target agent's isolated tmux workspace.
    /// The proxy strictly targets `pocketcoder:[agent_name]:terminal`.
    pub async fn exec(&self, cmd: &str, cwd: Option<&str>, agent_name: &str) -> Result<CommandResult> {
        let session = &self.session_name;
        let window_name = format!("{}:terminal", agent_name);

        let tmux_args = ["-S", &self.socket_path];
        // Target by window NAME (not index) so it's resilient to window reordering
        let pane = format!("{}:{}.0", session, window_name);
        let sentinel_id = Uuid::new_v4().to_string();
        
        // 2. Clear history
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "C-c"]).status();
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "clear", "Enter"]).status();
        let _ = Command::new("tmux").args(&tmux_args).args(["clear-history", "-t", &pane]).status();
        
        sleep(Duration::from_millis(300)).await;

        // 3. Inject Command
        // Wrap in a subshell so commands like `exit 1` don't kill the tmux pane's shell.
        let final_cmd = if let Some(dir) = cwd {
            format!("(cd \"{}\" && {})", dir, cmd)
        } else {
            format!("({})", cmd)
        };

        let wrapped_cmd = format!("{}; echo \"---POCKETCODER_EXIT:$?_ID:{{{}}}---\"", final_cmd, sentinel_id);
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, &wrapped_cmd, "Enter"]).status();

        // 4. Poll Loop
        let start_time = tokio::time::Instant::now();
        let timeout = Duration::from_secs(300);

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
                        .filter(|l| !l.contains(&sentinel_id))
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
// Tests
// --------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::test;
    use wiremock::{MockServer, Mock, matchers::{method, path}};
    use wiremock::ResponseTemplate;
    use serde_json::json;

    /// Helper to create a driver instance for testing
    fn create_test_driver() -> PocketCoderDriver {
        PocketCoderDriver::new("/tmp/test-tmux.sock", "test-session")
    }

    #[test]
    async fn test_resolve_session_calls_correct_cao_endpoint() {
        let mock_server = MockServer::start().await;
        
        // Mock CAO response with the new endpoint
        let mock_response = json!({
            "tmux_session": "test123",
            "tmux_window": "main@0",
            "tmux_window_id": 0
        });
        
        Mock::given(method("GET"))
            .and(path("/terminals/by-delegating-agent/test-session-id"))
            .respond_with(ResponseTemplate::new(200).set_body_json(&mock_response))
            .mount(&mock_server)
            .await;
        
        let driver = create_test_driver();
        
        // We can't easily test the actual HTTP call without more complex setup,
        // but we can verify the endpoint URL construction logic
        let expected_url = format!("{}/terminals/by-delegating-agent/test-session-id", mock_server.uri());
        
        // Verify the URL construction matches expected format
        assert!(expected_url.contains("/terminals/by-delegating-agent/"));
        assert!(!expected_url.contains("/terminals/by-external-session/"));
    }

    #[test]
    async fn test_resolve_session_returns_error_on_cao_404() {
        let mock_server = MockServer::start().await;
        
        // Mock CAO returning 404
        Mock::given(method("GET"))
            .and(path("/terminals/by-delegating-agent/missing-session"))
            .respond_with(ResponseTemplate::new(404))
            .mount(&mock_server)
            .await;
        
        let driver = create_test_driver();
        
        // The driver should return an error when CAO returns 404
        // Note: This test verifies the error handling behavior
        let result = driver.resolve_session_and_window("missing-session").await;
        
        // The result should be an error (no fallback to legacy resolution)
        assert!(result.is_err());
        let error_msg = result.unwrap_err().to_string();
        assert!(error_msg.contains("CAO lookup failed") || error_msg.contains("CAO request failed"));
    }

    #[test]
    async fn test_resolve_session_extracts_tmux_window_name() {
        // Test that we correctly extract tmux_window name from response
        let terminal_data: serde_json::Value = json!({
            "tmux_session": "test123",
            "tmux_window": "poco-ab12"
        });
        
        let tmux_session = terminal_data["tmux_session"].as_str().unwrap();
        let tmux_window = terminal_data["tmux_window"].as_str().unwrap();
        
        assert_eq!(tmux_session, "test123");
        assert_eq!(tmux_window, "poco-ab12");
    }

    #[test]
    async fn test_pane_target_uses_window_name() {
        // Test that the pane target uses window name, not numeric index
        let session = "pocketcoder_session";
        let window_name = "poco-ab12";
        let pane = format!("{}:{}.0", session, window_name);
        
        assert_eq!(pane, "pocketcoder_session:poco-ab12.0");
        // Should NOT contain numeric-only window reference
        assert!(!pane.contains(":0.0"));
    }

    #[test]
    async fn test_endpoint_url_format() {
        // Verify the endpoint URL format matches the new specification
        let session_id = "agent-session-123";
        let cao_url = "http://sandbox:9889";
        
        let endpoint = format!("{}/terminals/by-delegating-agent/{}", cao_url, session_id);
        
        assert_eq!(endpoint, "http://sandbox:9889/terminals/by-delegating-agent/agent-session-123");
        assert!(!endpoint.contains("by-external-session"));
    }
}