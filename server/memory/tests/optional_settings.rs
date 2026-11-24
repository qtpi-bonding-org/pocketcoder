// SPDX-License-Identifier: AGPL-3.0-or-later

use std::collections::HashMap;

use axum::{
    body::Body,
    http::{HeaderValue, Request, StatusCode, header::HOST},
};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use pocket_memory::{
    MemoryKind, Repository, identity::MEMORY_CONTEXT_HEADER, mcp, service::MemoryService,
};
use rmcp::{
    RoleClient, ServiceExt,
    model::{CallToolRequestParams, ClientInfo},
    service::RunningService,
    transport::{
        StreamableHttpClientTransport, streamable_http_client::StreamableHttpClientTransportConfig,
    },
};
use tokio_util::sync::CancellationToken;
use tower::ServiceExt as _;

fn context_header(account: &str) -> HeaderValue {
    let json = serde_json::to_vec(&serde_json::json!({
        "version": 1,
        "account_id": account,
        "agent_profile_id": "profile",
        "agent_name": "Agent"
    }))
    .unwrap();
    HeaderValue::from_str(&URL_SAFE_NO_PAD.encode(json)).unwrap()
}

async fn connect(address: &str, account: &str) -> RunningService<RoleClient, ClientInfo> {
    let config = StreamableHttpClientTransportConfig::with_uri(format!("http://{address}/mcp"))
        .custom_headers(HashMap::from([(
            MEMORY_CONTEXT_HEADER,
            context_header(account),
        )]));
    ClientInfo::default()
        .serve(StreamableHttpClientTransport::from_config(config))
        .await
        .unwrap()
}

async fn start(repository: Repository, agent_edits: bool) -> (String, CancellationToken) {
    let cancellation = CancellationToken::new();
    let app = mcp::router_with_options(
        MemoryService::new(repository),
        cancellation.child_token(),
        mcp::RouterOptions {
            agent_edits,
            ..Default::default()
        },
    );
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap().to_string();
    let shutdown = cancellation.clone();
    tokio::spawn(async move {
        axum::serve(listener, app)
            .with_graceful_shutdown(shutdown.cancelled_owned())
            .await
            .unwrap();
    });
    (address, cancellation)
}

fn call(name: &'static str, arguments: &serde_json::Value) -> CallToolRequestParams {
    CallToolRequestParams::new(name).with_arguments(arguments.as_object().cloned().unwrap())
}

#[tokio::test]
async fn edit_tools_cannot_be_called_by_default() {
    let repository = Repository::open_in_memory().await.unwrap();
    let (address, cancellation) = start(repository.clone(), false).await;
    let client = connect(&address, "shared").await;
    let created = client
        .call_tool(call(
            "memory_create_observation",
            &serde_json::json!({"body": "keep me"}),
        ))
        .await
        .unwrap();
    let id = created.structured_content.unwrap()["id"].clone();
    let deleted = client
        .call_tool(call(
            "memory_delete",
            &serde_json::json!({"kind": "observation", "id": id}),
        ))
        .await;
    assert!(deleted.is_err());
    let id = id.as_str().unwrap();
    let kept = repository.get(MemoryKind::Observation, "shared", id).await;
    assert_eq!(kept.unwrap().body, "keep me");
    cancellation.cancel();
}

#[tokio::test]
async fn enabled_edit_tools_update_delete_and_stay_inside_the_account() {
    let repository = Repository::open_in_memory().await.unwrap();
    let (address, cancellation) = start(repository.clone(), true).await;
    let client = connect(&address, "shared").await;
    let tools = client.list_tools(Option::default()).await.unwrap().tools;
    assert_eq!(tools.len(), 10);

    let created = client
        .call_tool(call(
            "memory_create_observation",
            &serde_json::json!({"body": "port is 3000"}),
        ))
        .await
        .unwrap();
    let id = created.structured_content.unwrap()["id"].clone();
    let target = serde_json::json!({"kind": "observation", "id": id});

    let other = connect(&address, "someone-else").await;
    assert!(
        other
            .call_tool(call("memory_delete", &target))
            .await
            .is_err()
    );

    let updated = client
        .call_tool(call(
            "memory_update",
            &serde_json::json!({"kind": "observation", "id": id, "body": "port is 4000"}),
        ))
        .await
        .unwrap();
    assert_eq!(updated.structured_content.unwrap()["body"], "port is 4000");
    let found = client
        .call_tool(call("memory_search", &serde_json::json!({"query": "4000"})))
        .await
        .unwrap();
    let found = found.structured_content.unwrap();
    assert_eq!(found["matches"].as_array().unwrap().len(), 1);

    client
        .call_tool(call("memory_delete", &target))
        .await
        .unwrap();
    let id = id.as_str().unwrap();
    assert!(
        repository
            .get(MemoryKind::Observation, "shared", id)
            .await
            .is_err()
    );
    cancellation.cancel();
}

#[tokio::test]
async fn an_only_supporting_observation_cannot_be_deleted() {
    let repository = Repository::open_in_memory().await.unwrap();
    let (address, cancellation) = start(repository, true).await;
    let client = connect(&address, "shared").await;
    let created = client
        .call_tool(call(
            "memory_create_interpretation",
            &serde_json::json!({"body": "meaning", "new_observation_body": "fact"}),
        ))
        .await
        .unwrap();
    let id = created.structured_content.unwrap()["linked"][0]["id"].clone();
    assert!(
        client
            .call_tool(call(
                "memory_delete",
                &serde_json::json!({"kind": "observation", "id": id}),
            ))
            .await
            .is_err()
    );
    cancellation.cancel();
}

async fn status_for(host: &str, extra: &[&str]) -> StatusCode {
    let repository = Repository::open_in_memory().await.unwrap();
    let app = mcp::router_with_options(
        MemoryService::new(repository),
        CancellationToken::new(),
        mcp::RouterOptions {
            extra_allowed_hosts: extra.iter().map(|&host| host.to_owned()).collect(),
            ..Default::default()
        },
    );
    app.oneshot(
        Request::builder()
            .method("GET")
            .uri("/mcp")
            .header(HOST, host)
            .header(MEMORY_CONTEXT_HEADER, context_header("shared"))
            .body(Body::empty())
            .unwrap(),
    )
    .await
    .unwrap()
    .status()
}

#[tokio::test]
async fn extra_hosts_are_added_to_the_default_list() {
    let extra = ["memory.example:8000"];
    assert_eq!(
        status_for("memory.example:8000", &[]).await,
        StatusCode::FORBIDDEN
    );
    assert_ne!(
        status_for("memory.example:8000", &extra).await,
        StatusCode::FORBIDDEN
    );
    assert_ne!(
        status_for("pocket-memory:8000", &extra).await,
        StatusCode::FORBIDDEN
    );
    assert_eq!(
        status_for("evil.example", &extra).await,
        StatusCode::FORBIDDEN
    );
}
