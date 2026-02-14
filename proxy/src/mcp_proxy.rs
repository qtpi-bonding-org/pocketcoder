use axum::{
    extract::{ws::{Message, WebSocket, WebSocketUpgrade}, State},
    response::Response,
};
use futures_util::{StreamExt, SinkExt}; // Trait for split() and send()
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::Command;
use std::sync::Arc;
use crate::AppState;

use serde::Deserialize;

#[derive(Deserialize)]
pub struct McpQuery {
    #[serde(alias = "sessionId")]
    pub session_id: Option<String>,
}

/// The Persistent WebSocket Relay (MCP-Relay-Tunnel)
pub async fn mcp_ws_handler(
    ws: WebSocketUpgrade,
    State(_state): State<Arc<AppState>>,
) -> Response {
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(socket: WebSocket) {
    println!("🔌 [MCP-Proxy] Client connected via WebSocket.");

    // 1. Spawn SSH Process
    let mut child = match Command::new("ssh")
        .args([
            "-T", 
            "-p", "2222",
            "-i", "/ssh_keys/id_rsa",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "worker@sandbox",
            "cd /app/cao && /usr/local/bin/uv run cao-mcp-server"
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn() {
            Ok(c) => c,
            Err(e) => {
                eprintln!("❌ [MCP-Proxy] Failed to spawn SSH: {}", e);
                return;
            }
        };

    println!("🚀 [MCP-Proxy] SSH Tunnel established to Sandbox.");

    let mut ssh_stdin = child.stdin.take().expect("Failed to open SSH stdin");
    let ssh_stdout = child.stdout.take().expect("Failed to open SSH stdout");

    // 2. Split Socket for Select Loop
    let (mut ws_sender, mut ws_receiver) = socket.split();
    let mut ssh_reader = BufReader::new(ssh_stdout).lines();

    loop {
        tokio::select! {
            // A. WebSocket -> SSH
            Some(msg) = ws_receiver.next() => {
                match msg {
                    Ok(Message::Text(text)) => {
                        // Forward text to SSH Stdin
                        if let Err(e) = ssh_stdin.write_all(text.as_bytes()).await {
                            eprintln!("❌ [MCP-Proxy] Write to SSH failed: {}", e);
                            break;
                        }
                        // MCP relies on newlines for framing
                        if let Err(e) = ssh_stdin.write_all(b"\n").await {
                            eprintln!("❌ [MCP-Proxy] Flush to SSH failed: {}", e);
                            break;
                        }
                    }
                    Ok(Message::Close(_)) => {
                        println!("🔌 [MCP-Proxy] Client disconnected.");
                        break;
                    }
                    Err(e) => {
                        eprintln!("❌ [MCP-Proxy] WebSocket Error: {}", e);
                        break;
                    }
                    _ => {} // Ignore binary/ping/pong
                }
            }

            // B. SSH -> WebSocket
            line = ssh_reader.next_line() => {
                match line {
                    Ok(Some(text)) => {
                        if let Err(e) = ws_sender.send(Message::Text(text)).await {
                            eprintln!("❌ [MCP-Proxy] Send to WS failed: {}", e);
                            break;
                        }
                    }
                    Ok(None) => {
                        println!("💀 [MCP-Proxy] SSH Process exited.");
                        break;
                    }
                    Err(e) => {
                        eprintln!("❌ [MCP-Proxy] SSH Read Error: {}", e);
                        break;
                    }
                }
            }
        }
    }

    // Cleanup
    let _ = child.kill().await;
    println!("👋 [MCP-Proxy] Session ended.");
}
