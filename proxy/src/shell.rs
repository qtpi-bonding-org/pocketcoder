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


/* @pocketcoder-core: Shell Bridge. The client-side logic that routes commands from the Brain to the Proxy. */
//! # Shell Bridge
//! This module provides the client-side logic for the `pocketcoder shell` command,
//! which routes commands from the reasoning engine to the persistent proxy.
use serde_json;
use std::env;
use std::io::{self, Write};
use std::process;
use anyhow::{Result};
use crate::driver::{ExecRequest, ExecResponse};

pub fn run(command: Option<String>, args: Vec<String>) -> Result<()> {
    // 1. Determine the Command string
    let cmd = if let Some(c) = command {
        c
    } else if !args.is_empty() {
        // SHELL-AWARE LOGIC:
        if args.len() >= 2 && args[0] == "-c" {
            // PATH 1: The Sacred String. 
            // If called as 'sh -c "cmd"', we trust the command string exactly as passed.
            args[1].clone()
        } else {
            // PATH 2: Positional Arguments.
            // Mimic shell behavior by escaping each arg and joining with spaces.
            args.iter()
                .map(|a| format!("'{}'", a.replace("'", "'\\''")))
                .collect::<Vec<_>>()
                .join(" ")
        }
    } else {
        eprintln!("\x1b[31m🔥 [Firewall Blocked]: Interactive or raw shell invocation is restricted for security. Always execute commands via 'bash -c \"command\"'.\x1b[0m");
        process::exit(1);
    };

    let cwd = env::current_dir().unwrap_or_default().to_string_lossy().to_string();
    let usage_id = env::var("POCKETCODER_USAGE_ID").ok();
    let session_id = env::var("OPENCODE_SESSION_ID").ok();

    let request = ExecRequest {
        cmd,
        cwd,
        usage_id,
        session_id,
    };

    let proxy_url = env::var("PROXY_URL").unwrap_or_else(|_| "http://proxy:3001".to_string());

    // 2. The Proxy Request (Synchronous)
    match ureq::post(&format!("{}/exec", proxy_url))
        .send_json(serde_json::to_value(request).unwrap())
    {
        Ok(res) => {
            let response: ExecResponse = match res.into_json() {
                Ok(j) => j,
                Err(e) => {
                    eprintln!("\x1b[31m❌ [Bridge Error]: Invalid JSON from Proxy: {}\x1b[0m", e);
                    process::exit(1);
                }
            };

            if let Some(err) = response.error {
                eprintln!("\x1b[31m🔥 [Firewall Blocked]: {}\x1b[0m", err);
                process::exit(1);
            }

            if let Some(stdout) = response.stdout {
                print!("{}", stdout);
                io::stdout().flush().unwrap();
            }

            process::exit(response.exit_code.unwrap_or(0));
        }
        Err(e) => {
            eprintln!("\x1b[31m🔥 [Bridge Error]: Connection to Proxy failed ({}). Is the server running?\x1b[0m", e);
            process::exit(1);
        }
    }
}
