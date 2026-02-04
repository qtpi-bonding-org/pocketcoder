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

    // 1. Restricted Mode: Block interactive or non-conforming calls
    if args.len() < 3 || args[1] != "-c" {
        eprintln!("\x1b[31m🔥 [Firewall Blocked]: Interactive or raw shell invocation is restricted for security. Always execute commands via 'bash -c \"command\"'.\x1b[0m");
        process::exit(1);
    }

    let cmd = args[2].clone();
    let cwd = env::current_dir().unwrap_or_default().to_string_lossy().to_string();
    let usage_id = env::var("POCKETCODER_USAGE_ID").ok();

    let request = ExecRequest {
        cmd,
        cwd,
        usage_id,
    };

    // 2. The Bridge (Rust Synchronous Request)
    match ureq::post("http://gateway:3001/exec")
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
