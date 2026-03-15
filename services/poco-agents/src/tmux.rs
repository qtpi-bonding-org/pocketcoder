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

// @pocketcoder-core: Tmux Manager. Tmux session and window management for agent isolation.
use std::process::Command;
use tracing::debug;

fn tmux_cmd(socket: &str) -> Command {
    let mut cmd = Command::new("tmux");
    cmd.arg("-S").arg(socket);
    cmd
}

pub fn new_window(socket: &str, session: &str, window_name: &str, working_dir: &str) -> bool {
    let status = tmux_cmd(socket)
        .args(["new-window", "-t", session, "-n", window_name, "-d"])
        .args(["-c", working_dir])
        .status();

    if let Ok(s) = &status {
        if s.success() {
            // Set remain-on-exit so we can read the exit status
            let _ = tmux_cmd(socket)
                .args([
                    "set-option",
                    "-t",
                    &format!("{session}:{window_name}"),
                    "remain-on-exit",
                    "on",
                ])
                .status();
            return true;
        }
    }
    debug!("new_window failed: {:?}", status);
    false
}

/// Send a command to a tmux window using load-buffer + paste-buffer for safe multi-line delivery.
pub fn send_keys(socket: &str, session: &str, window: &str, cmd: &str) -> bool {
    // Write command to a temp file, then load-buffer + paste-buffer
    let tmp = format!("/tmp/tmux-cmd-{}", uuid::Uuid::new_v4());
    // Append newline so the command executes
    let cmd_with_newline = format!("{cmd}\n");
    if std::fs::write(&tmp, &cmd_with_newline).is_err() {
        return false;
    }

    let target = format!("{session}:{window}");

    let load = tmux_cmd(socket)
        .args(["load-buffer", &tmp])
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    if !load {
        let _ = std::fs::remove_file(&tmp);
        return false;
    }

    let paste = tmux_cmd(socket)
        .args(["paste-buffer", "-t", &target])
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    let _ = std::fs::remove_file(&tmp);
    paste
}

pub fn window_exists(socket: &str, session: &str, window: &str) -> bool {
    let output = tmux_cmd(socket)
        .args([
            "list-windows",
            "-t",
            session,
            "-F",
            "#{window_name}",
        ])
        .output();

    match output {
        Ok(o) => {
            let stdout = String::from_utf8_lossy(&o.stdout);
            stdout.lines().any(|line| line.trim() == window)
        }
        Err(_) => false,
    }
}

pub fn capture_pane(socket: &str, session: &str, window: &str, lines: u32) -> Option<String> {
    let target = format!("{session}:{window}");
    let start = format!("-{lines}");

    let output = tmux_cmd(socket)
        .args([
            "capture-pane",
            "-t",
            &target,
            "-p",
            "-S",
            &start,
        ])
        .output()
        .ok()?;

    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        None
    }
}

pub fn kill_window(socket: &str, session: &str, window: &str) -> bool {
    let target = format!("{session}:{window}");
    tmux_cmd(socket)
        .args(["kill-window", "-t", &target])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}
