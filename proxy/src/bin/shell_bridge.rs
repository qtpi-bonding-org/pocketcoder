use std::env;
use std::io::{self, Write};
use std::process;
use serde::{Deserialize, Serialize};

#[derive(Serialize)]
struct ExecRequest {
    cmd: String,
    cwd: String,
    usage_id: Option<String>,
}

#[derive(Deserialize)]
struct ExecResponse {
    stdout: Option<String>,
    exit_code: Option<i32>,
    error: Option<String>,
}

fn main() {
    let args: Vec<String> = env::args().collect();

    // 1. Determine the Command string
    let cmd = if args.len() >= 3 && args[1] == "-c" {
        // Standard shell call: pocketcoder-shell -c "command"
        args[2].clone()
    } else if args.len() >= 2 {
        // Direct tool call: /usr/bin/glob arg1 arg2
        // We use the basename of args[0] in case it's a path like /usr/bin/glob
        let binary = std::path::Path::new(&args[0])
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| args[0].clone());
        
        let mut full_cmd = binary;
        for arg in args.iter().skip(1) {
            full_cmd.push(' ');
            // Simple quoting for safety
            full_cmd.push_str(&format!("'{}'", arg.replace("'", "'\\''")));
        }
        full_cmd
    } else {
        eprintln!("\x1b[31m🔥 [Firewall Blocked]: Interactive or raw shell invocation is restricted for security. Always execute commands via 'bash -c \"command\"'.\x1b[0m");
        process::exit(1);
    };

    let cwd = env::current_dir().unwrap_or_default().to_string_lossy().to_string();
    let usage_id = env::var("POCKETCODER_USAGE_ID").ok();

    let request = ExecRequest {
        cmd,
        cwd,
        usage_id,
    };

    // 2. The Proxy (Rust Synchronous Request)
    match ureq::post("http://proxy:3001/exec")
        .send_json(serde_json::to_value(request).unwrap())
    {
        Ok(res) => {
            let response: ExecResponse = match res.into_json() {
                Ok(j) => j,
                Err(e) => {
                    eprintln!("\x1b[31m�� [Bridge Error]: Invalid JSON from Gateway: {}\x1b[0m", e);
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
            eprintln!("\x1b[31m🔥 [Bridge Error]: Connection to Gateway Failed: {}\x1b[0m", e);
            process::exit(1);
        }
    }
}
