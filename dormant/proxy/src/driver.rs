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
        
        matches!(status, Ok(s) if s.success())
    }

    /// Execute a command in the target agent's isolated tmux workspace.
    /// The proxy targets `pocketcoder:{agent_name}-terminal.0`.
    pub async fn exec(&self, cmd: &str, cwd: Option<&str>, agent_name: &str) -> Result<CommandResult> {
        let session = &self.session_name;
        let window_name = format!("{}-terminal", agent_name);

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
            // Validate cwd contains only safe path characters
            if !dir.chars().all(|c| c.is_alphanumeric() || "/_.-+ ".contains(c)) {
                return Err(anyhow!("Invalid working directory path"));
            }
            format!("(cd \"{}\" && {})", dir, cmd)
        } else {
            format!("({})", cmd)
        };

        let out_file = format!("/tmp/pocketcoder_out_{}.txt", sentinel_id);
        let wrapped_cmd = format!("{} > {} 2>&1; echo \"---POCKETCODER_EXIT:$?_ID:{{{}}}---\" >> {}", final_cmd, out_file, sentinel_id, out_file);
        let _ = Command::new("tmux").args(&tmux_args).args(["send-keys", "-t", &pane, &wrapped_cmd, "Enter"]).status();

        // 4. Poll Loop
        let start_time = tokio::time::Instant::now();
        let timeout = Duration::from_secs(300);

        loop {
            if start_time.elapsed() > timeout {
                let _ = std::fs::remove_file(&out_file);
                return Err(anyhow!("Command execution timed out (Sandbox)."));
            }

            let output = Command::new("tmux")
                .args(&tmux_args)
                .args(["capture-pane", "-p", "-t", &pane, "-S", "-"])
                .output()?;

            let content = match std::fs::read_to_string(&out_file) {
                Ok(c) => c,
                Err(_) => { sleep(Duration::from_millis(200)).await; continue; }
            };

            if let Some(pos) = content.find("---POCKETCODER_EXIT") {
                if content.contains(&sentinel_id) {
                    let sub = &content[pos + 3..]; // skip "---"
                    let exit_code_part = sub.split(':').nth(1).unwrap_or("0").split('_').next().unwrap_or("0");
                    let exit_code = exit_code_part.parse::<i32>().unwrap_or(0);

                    let result_output = content[..pos].trim().to_string();

                    let _ = std::fs::remove_file(&out_file);
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

    #[test]
    fn test_pane_target_format() {
        // Verify pane target uses agent-terminal naming (no colons in window name)
        let session = "pocketcoder";
        let agent_name = "poco";
        let window_name = format!("{}-terminal", agent_name);
        let pane = format!("{}:{}.0", session, window_name);

        assert_eq!(pane, "pocketcoder:poco-terminal.0");
        // Window name must not contain colons (ambiguous in tmux targeting)
        assert!(!window_name.contains(':'));
    }

    #[test]
    fn test_sentinel_pattern_parsing() {
        // Verify sentinel pattern is correctly parsed from output file content
        let sentinel_id = "abc-123";
        let content = format!("hello world\n---POCKETCODER_EXIT:0_ID:{{{}}}---\n", sentinel_id);

        let pos = content.find("---POCKETCODER_EXIT").unwrap();
        let sub = &content[pos + 3..]; // skip "---"
        let exit_code_part = sub.split(':').nth(1).unwrap_or("0").split('_').next().unwrap_or("0");
        let exit_code = exit_code_part.parse::<i32>().unwrap();
        let result_output = content[..pos].trim().to_string();

        assert_eq!(exit_code, 0);
        assert_eq!(result_output, "hello world");
    }

    #[test]
    fn test_sentinel_pattern_nonzero_exit() {
        let sentinel_id = "def-456";
        let content = format!("---POCKETCODER_EXIT:127_ID:{{{}}}---\n", sentinel_id);

        let pos = content.find("---POCKETCODER_EXIT").unwrap();
        let sub = &content[pos + 3..];
        let exit_code_part = sub.split(':').nth(1).unwrap_or("0").split('_').next().unwrap_or("0");
        let exit_code = exit_code_part.parse::<i32>().unwrap();
        let result_output = content[..pos].trim().to_string();

        assert_eq!(exit_code, 127);
        assert_eq!(result_output, "");
    }

    #[test]
    fn test_cwd_wrapping() {
        // Verify cwd wrapping format
        let cmd = "ls";
        let cwd = "/tmp";
        let final_cmd = format!("(cd \"{}\" && {})", cwd, cmd);
        assert_eq!(final_cmd, "(cd \"/tmp\" && ls)");
    }

    #[test]
    fn test_cwd_validation_safe_paths() {
        let safe_paths = vec!["/tmp", "/home/user/project", "/opt/my-app_v2", "/a/b.c"];
        for path in safe_paths {
            assert!(path.chars().all(|c| c.is_alphanumeric() || "/_.-+ ".contains(c)),
                "Path should be valid: {}", path);
        }
    }

    #[test]
    fn test_cwd_validation_rejects_metacharacters() {
        let bad_paths = vec![
            "/tmp/$(whoami)",
            "/tmp\"; rm -rf /; echo \"",
            "/tmp`id`",
            "/tmp;ls",
            "/tmp&&echo",
            "/tmp|cat",
        ];
        for path in bad_paths {
            assert!(!path.chars().all(|c| c.is_alphanumeric() || "/_.-+ ".contains(c)),
                "Path should be rejected: {}", path);
        }
    }
}