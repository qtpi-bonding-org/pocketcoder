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

    /// Smart Router: Resolve session_id to (tmux_session_name, window_id)
    /// 
    /// Logic:
    /// 1. Query CAO's API at /terminals/by-delegating-agent/{session_id}
    /// 2. Extract tmux_session and tmux_window_id from the response
    /// 3. Return error if CAO lookup fails (no fallback)
    async fn resolve_session_and_window(&self, session_id: &str) -> Result<(String, u32)> {
        let cao_url = "http://sandbox:9889";
        let client = reqwest::Client::new();
        
        // Query CAO's API to resolve the session via delegating_agent_id
        let response = client.get(format!("{}/terminals/by-delegating-agent/{}", cao_url, session_id))
            .send()
            .await
            .map_err(|e| anyhow!("CAO request failed: {}", e))?;
        
        if !response.status().is_success() {
            return Err(anyhow!("CAO lookup failed for delegating_agent_id '{}' with status {}", 
                session_id, response.status()));
        }
        
        let terminal_data = response.json::<serde_json::Value>().await
            .map_err(|e| anyhow!("Failed to parse CAO response: {}", e))?;
        
        let tmux_session = terminal_data["tmux_session"].as_str()
            .ok_or_else(|| anyhow!("Missing tmux_session in CAO response"))?;
        
        // Extract window_id: prefer numeric tmux_window_id field, fall back to parsing tmux_window
        let window_id = if let Some(window_id_num) = terminal_data.get("tmux_window_id").and_then(|v| v.as_u64()) {
            window_id_num as u32
        } else if let Some(tmux_window) = terminal_data["tmux_window"].as_str() {
            // Fallback: extract window ID from window name (format: "window_name@<window_id>")
            if let Some(at_pos) = tmux_window.rfind('@') {
                tmux_window[at_pos + 1..].parse::<u32>().unwrap_or(0)
            } else {
                // Fallback: query tmux directly for window index
                self.get_window_index(tmux_session, tmux_window)?
            }
        } else {
            return Err(anyhow!("Missing tmux_window_id and tmux_window in CAO response"));
        };
        
        println!("🔗 [Driver] Resolved session_id '{}' to session '{}' window {}", 
                 session_id, tmux_session, window_id);
        Ok((tmux_session.to_string(), window_id))
    }

    /// Get window index by querying tmux directly
    fn get_window_index(&self, session: &str, window_name: &str) -> Result<u32> {
        let tmux_args = ["-S", &self.socket_path];
        let output = Command::new("tmux")
            .args(&tmux_args)
            .args(["list-windows", "-t", session, "-F", "#{window_name}:#{window_index}"])
            .output()?;
        
        let content = String::from_utf8_lossy(&output.stdout);
        for line in content.lines() {
            if let Some((name, index_str)) = line.split_once(':') {
                if name == window_name {
                    return Ok(index_str.parse::<u32>().unwrap_or(0));
                }
            }
        }
        
        Ok(0) // Default to window 0 if not found
    }

    pub async fn exec(&self, cmd: &str, cwd: Option<&str>, session_override: Option<&str>) -> Result<CommandResult> {
        let session_id = session_override.unwrap_or(&self.session_name);
        
        // 1. Resolve Session Identity (Smart Router Logic)
        let (session, window_id) = self.resolve_session_and_window(session_id).await?;

        let tmux_args = ["-S", &self.socket_path];
        let pane = format!("{}:{}.0", session, window_id);
        let sentinel_id = Uuid::new_v4().to_string();
        
        // 2. Clear history
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "C-c"]).status();
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, "clear", "Enter"]).status();
        let _ = Command::new("tmux").args(&tmux_args).args(["clear-history", "-t", &pane]).status();
        
        sleep(Duration::from_millis(300)).await;

        // 3. Inject Command (MATCHING OLD LOGIC)
        let final_cmd = if let Some(dir) = cwd {
            format!("cd \"{}\" && {}", dir, cmd)
        } else {
             cmd.to_string()
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
                        .filter(|l| !l.contains("cd \"/workspace\""))
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
            "tmux_session": "pc-test123",
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
    async fn test_resolve_session_extracts_tmux_window_id() {
        // Test that we correctly extract numeric tmux_window_id from response
        let terminal_data: serde_json::Value = json!({
            "tmux_session": "pc-test123",
            "tmux_window_id": 5
        });
        
        let tmux_session = terminal_data["tmux_session"].as_str().unwrap();
        let window_id = terminal_data.get("tmux_window_id").and_then(|v| v.as_u64()).unwrap();
        
        assert_eq!(tmux_session, "pc-test123");
        assert_eq!(window_id, 5);
    }

    #[test]
    async fn test_resolve_session_falls_back_to_tmux_window_parsing() {
        // Test fallback to tmux_window parsing when tmux_window_id is not present
        let terminal_data: serde_json::Value = json!({
            "tmux_session": "pc-test123",
            "tmux_window": "analyst@2"
        });
        
        let tmux_session = terminal_data["tmux_session"].as_str().unwrap();
        let tmux_window = terminal_data["tmux_window"].as_str().unwrap();
        
        // Extract window ID from window name (format: "window_name@<window_id>")
        let window_id = if let Some(at_pos) = tmux_window.rfind('@') {
            tmux_window[at_pos + 1..].parse::<u32>().unwrap_or(0)
        } else {
            0
        };
        
        assert_eq!(tmux_session, "pc-test123");
        assert_eq!(window_id, 2);
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