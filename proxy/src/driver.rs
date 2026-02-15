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
pub struct NotifyRequest {
    pub session_id: String,
    pub event_type: String,
    pub payload: serde_json::Value,
}

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

    pub async fn exec(&self, cmd: &str, cwd: Option<&str>, session_override: Option<&str>) -> Result<CommandResult> {
        let session = session_override.unwrap_or(&self.session_name);
        let tmux_args = ["-S", &self.socket_path];
        
        // 1. Connectivity Check
        let status = Command::new("tmux")
            .args(&tmux_args)
            .args(["has-session", "-t", session])
            .status();

        if !status.is_ok() || !status.unwrap().success() {
             println!("❌ [Driver] FATAL: Could not find TMUX session '{}' on socket {}.", session, self.socket_path);
             println!("💡 [Driver] Ensure the Sandbox container is running and has initialized the session.");
             return Err(anyhow!("Sandbox TMUX session not found. Execution aborted for safety."));
        }

        let pane = format!("{}:0.0", session);
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
