// SPDX-License-Identifier: AGPL-3.0-or-later

// Regression test for the docker-compose deployment shape: every harness
// reaches this service at http://pocket-memory:8000/mcp (the compose
// service hostname, hooks.memoryURL in the Go backend) rather than a
// loopback address. rmcp's streamable-http server rejects any Host header
// outside its configured allowlist as DNS-rebinding protection -- this
// test would have caught the 2026-08-28 regression where the allowlist
// defaulted to loopback-only and every real harness got a 403 "Host
// header is not allowed" trying to start the memory MCP server.
//
// tower::ServiceExt::oneshot drives the router directly (no real socket),
// since rmcp validates the Host header before any method/protocol
// dispatch (see StreamableHttpService::handle) -- a bare GET with the
// right identity header is enough to exercise it.

use axum::{
    body::Body,
    http::{Request, StatusCode, header::HOST},
};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use pocket_memory::{Repository, identity::MEMORY_CONTEXT_HEADER, mcp, service::MemoryService};
use tokio_util::sync::CancellationToken;
use tower::ServiceExt;

fn context_header_value() -> String {
    let json = serde_json::to_vec(&serde_json::json!({
        "version": 1,
        "account_id": "family",
        "agent_profile_id": "poco-profile",
        "agent_name": "Poco"
    }))
    .unwrap();
    URL_SAFE_NO_PAD.encode(json)
}

async fn request_with_host(host: &str) -> StatusCode {
    let repository = Repository::open_in_memory().await.unwrap();
    let app = mcp::router(MemoryService::new(repository), CancellationToken::new());

    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri("/mcp")
                .header(HOST, host)
                .header(MEMORY_CONTEXT_HEADER, context_header_value())
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    response.status()
}

#[tokio::test]
async fn accepts_the_docker_compose_service_hostname() {
    // Must not be 403 -- this is exactly the hostname every harness uses
    // (server/pocketbase/internal/hooks/mcp_services.go's memoryURL).
    assert_ne!(
        request_with_host("pocket-memory:8000").await,
        StatusCode::FORBIDDEN,
        "the docker-compose service hostname must be in the Host allowlist"
    );
}

#[tokio::test]
async fn still_rejects_an_unrecognized_host() {
    // Confirms the fix didn't disable the allowlist outright -- DNS
    // rebinding protection must still reject a host nobody expects.
    assert_eq!(
        request_with_host("evil.example").await,
        StatusCode::FORBIDDEN
    );
}
