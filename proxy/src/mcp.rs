use axum::{
    extract::Query,
    response::{sse::{Event, Sse}, IntoResponse},
};
use futures_util::stream::Stream;
use tokio_stream::StreamExt;
use serde::Deserialize;
use uuid::Uuid;
// We'll keep sharing types if needed, or define locally

#[derive(Deserialize)]
pub struct SseQuery {
    #[serde(rename = "sessionId")]
    pub session_id: Option<String>,
}

pub async fn mcp_sse_relay_handler(
    Query(query): Query<SseQuery>,
) -> Sse<impl Stream<Item = Result<Event, anyhow::Error>>> {
    let session_id = query.session_id.unwrap_or_else(|| Uuid::new_v4().to_string());
    println!("🔌 [MCP-Relay] Initializing SSE link for session: {}", session_id);

    let client = reqwest::Client::new();
    let upstream_url = format!("http://sandbox:9888/sse?session_id={}", session_id);
    println!("📡 [MCP-Relay] Upstream: {}", upstream_url);

    let stream = async_stream::try_stream! {
        let mut response = client.get(&upstream_url).send().await?
            .bytes_stream();

        let mut line_buffer = String::new();

        while let Some(item) = response.next().await {
            let chunk = item?;
            let text = String::from_utf8_lossy(&chunk);
            line_buffer.push_str(&text);

            while let Some(pos) = line_buffer.find('\n') {
                let line = line_buffer.drain(..pos + 1).collect::<String>();
                let line_trimmed = line.trim();

                if line_trimmed.starts_with("data: /messages/") {
                    let rewritten = line_trimmed.replace("/messages/", "/mcp/messages/");
                    println!("🔄 [MCP-Relay] REWRITE: {} -> {}", line_trimmed, rewritten);
                    yield Event::default().data(&rewritten[6..]).event("endpoint");
                } else if line_trimmed.starts_with("event: endpoint") {
                    yield Event::default().event("endpoint");
                } else if line_trimmed.starts_with("data: ") {
                    yield Event::default().data(&line_trimmed[6..]);
                } else if line_trimmed.starts_with("event: ") {
                     yield Event::default().event(&line_trimmed[7..]);
                }
            }
        }
    };

    Sse::new(stream)
}

pub async fn mcp_message_proxy_handler(
    Query(query): Query<SseQuery>,
    headers: axum::http::HeaderMap,
    body: axum::body::Bytes,
) -> impl axum::response::IntoResponse {
    let session_id = query.session_id.unwrap_or_else(|| "unknown".to_string());
    println!("🎯 [MCP-Relay] Forwarding JSON-RPC for session: {}", session_id);

    let client = reqwest::Client::new();
    let upstream_url = format!("http://sandbox:9888/messages/?session_id={}", session_id);

    let mut req_builder = client.post(&upstream_url).body(body);
    for (key, value) in headers.iter() {
        if key.as_str().to_lowercase() != "host" {
            req_builder = req_builder.header(key.clone(), value.clone());
        }
    }

    match req_builder.send().await {
        Ok(res) => {
            let status = axum::http::StatusCode::from_u16(res.status().as_u16()).unwrap_or(axum::http::StatusCode::OK);
            let mut res_headers = axum::http::HeaderMap::new();
            for (key, value) in res.headers().iter() {
                res_headers.insert(key.clone(), value.clone());
            }
            let bytes = res.bytes().await.unwrap_or_default();
            (status, res_headers, bytes).into_response()
        }
        Err(e) => {
            println!("❌ [MCP-Relay] Forwarding Error: {}", e);
            (axum::http::StatusCode::BAD_GATEWAY, e.to_string()).into_response()
        }
    }
}
