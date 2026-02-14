use std::env;
use anyhow::{Result, anyhow};
use futures_util::{StreamExt, SinkExt};
use tokio::io::{self, AsyncBufReadExt, AsyncWriteExt};
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use url::Url;

pub async fn run(_session_id: Option<String>) -> Result<()> {
    // 1. Determine Proxy WebSocket URL
    let proxy_url = env::var("PROXY_URL").unwrap_or_else(|_| "http://proxy:3001".to_string());
    // Convert http(s) -> ws(s)
    let ws_url = if proxy_url.starts_with("https") {
        proxy_url.replace("https://", "wss://")
    } else {
        proxy_url.replace("http://", "ws://")
    };
    
    let endpoint = format!("{}/mcp/ws", ws_url);
    eprintln!("📟 [MCP-Stdio-Client] Connecting to Proxy at: {}", endpoint);

    let (ws_stream, _) = connect_async(endpoint).await?;
    eprintln!("✅ [MCP-Stdio-Client] Connected.");

    let (mut write_ws, mut read_ws) = ws_stream.split();

    // 2. Setup Stdio Streams
    let stdin = io::stdin();
    let mut stdin_reader = io::BufReader::new(stdin).lines();
    let mut stdout = io::stdout();

    // 3. Main Loop: Stdio <-> WebSocket
    loop {
        tokio::select! {
            // A. Stdin -> WebSocket
            line = stdin_reader.next_line() => {
                match line {
                    Ok(Some(msg)) => {
                        let trimmed = msg.trim();
                        if !trimmed.is_empty() {
                            // eprintln!("➡️ [MCP-Client] Sending: {:.50}...", trimmed);
                            write_ws.send(Message::Text(trimmed.to_string())).await?;
                        }
                    }
                    Ok(None) => break, // EOF
                    Err(e) => return Err(anyhow!("Stdin Error: {}", e)),
                }
            }

            // B. WebSocket -> Stdout
            msg = read_ws.next() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        // eprintln!("⬅️ [MCP-Client] Received: {:.50}...", text);
                        stdout.write_all(text.as_bytes()).await?;
                        stdout.write_all(b"\n").await?;
                        stdout.flush().await?;
                    }
                    Some(Ok(Message::Binary(bin))) => {
                        stdout.write_all(&bin).await?;
                        stdout.flush().await?;
                    }
                    Some(Ok(Message::Close(_))) => {
                        eprintln!("❌ [MCP-Client] Server closed connection.");
                        break;
                    }
                    Some(Err(e)) => return Err(anyhow!("WebSocket Error: {}", e)),
                    None => break, // Stream closed
                    _ => {} // Ignore Ping/Pong
                }
            }
        }
    }

    Ok(())
}
