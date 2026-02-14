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
        // OpenCode often calls: /bin/sh -c "command"
        // We need to strip the interpreter and the -c flag to get the raw command.
        let mut actual_args = args.as_slice();
        
        // Strip common interpreters
        if !actual_args.is_empty() && (actual_args[0].ends_with("sh") || actual_args[0].ends_with("bash")) {
            actual_args = &actual_args[1..];
        }

        // Strip -c flag
        if !actual_args.is_empty() && actual_args[0] == "-c" {
            if actual_args.len() > 1 {
                actual_args[1].to_string()
            } else {
                return Err(anyhow::anyhow!("Received -c but no command following it."));
            }
        } else {
            // Reconstruct if it wasn't a simple -c call
            let binary = std::path::Path::new(&args[0])
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_else(|| args[0].clone());
            
            let mut full_cmd = binary;
            for arg in args.iter().skip(1) {
                full_cmd.push(' ');
                full_cmd.push_str(&format!("'{}'", arg.replace("'", "'\\''")));
            }
            full_cmd
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
