// SPDX-License-Identifier: AGPL-3.0-or-later

use std::collections::{BTreeSet, HashMap};

use axum::http::HeaderValue;
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use pocket_memory::{
    MemoryKind, MemoryRecord, Repository, identity::MEMORY_CONTEXT_HEADER, mcp,
    service::MemoryService,
};
use rmcp::{
    ServiceExt,
    model::{CallToolRequestParams, ClientInfo},
    transport::{
        StreamableHttpClientTransport, streamable_http_client::StreamableHttpClientTransportConfig,
    },
};
use tokio_util::sync::CancellationToken;

fn context_header() -> HeaderValue {
    let json = serde_json::to_vec(&serde_json::json!({
        "version": 1,
        "account_id": "family",
        "agent_profile_id": "poco-profile",
        "agent_name": "Poco"
    }))
    .unwrap();
    HeaderValue::from_str(&URL_SAFE_NO_PAD.encode(json)).unwrap()
}

#[tokio::test]
async fn streamable_http_initializes_and_attributes_a_write() {
    let repository = Repository::open_in_memory().await.unwrap();
    let cancellation = CancellationToken::new();
    let app = mcp::router(
        MemoryService::new(repository.clone()),
        cancellation.child_token(),
    );
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let shutdown = cancellation.clone();
    let server = tokio::spawn(async move {
        axum::serve(listener, app)
            .with_graceful_shutdown(shutdown.cancelled_owned())
            .await
            .unwrap();
    });

    let config = StreamableHttpClientTransportConfig::with_uri(format!("http://{address}/mcp"))
        .custom_headers(HashMap::from([(MEMORY_CONTEXT_HEADER, context_header())]));
    let client = ClientInfo::default()
        .serve(StreamableHttpClientTransport::from_config(config))
        .await
        .unwrap();

    let listed = client.list_tools(Option::default()).await.unwrap();
    let tool_names = listed
        .tools
        .iter()
        .map(|tool| tool.name.to_string())
        .collect::<BTreeSet<_>>();
    assert_eq!(
        tool_names,
        [
            "memory_create_interpretation",
            "memory_create_observation",
            "memory_get_interpretation",
            "memory_get_observation",
            "memory_link",
            "memory_list",
            "memory_search",
            "memory_unlink",
        ]
        .into_iter()
        .map(str::to_owned)
        .collect()
    );

    let result = client
        .call_tool(
            CallToolRequestParams::new("memory_create_observation").with_arguments(
                serde_json::json!({"body": "remember the blue gate"})
                    .as_object()
                    .cloned()
                    .unwrap(),
            ),
        )
        .await
        .unwrap();
    let record: MemoryRecord = serde_json::from_value(result.structured_content.unwrap()).unwrap();
    assert_eq!(record.account_id, "family");
    assert_eq!(record.agent_profile_id, "poco-profile");
    assert_eq!(record.agent_name, "Poco");

    let stored = repository
        .get(MemoryKind::Observation, "family", &record.id)
        .await
        .unwrap();
    assert_eq!(stored.body, "remember the blue gate");

    let existing_result = client
        .call_tool(
            CallToolRequestParams::new("memory_create_interpretation").with_arguments(
                serde_json::json!({
                    "body": "the blue gate marks the entrance",
                    "existing_observation_id": record.id
                })
                .as_object()
                .cloned()
                .unwrap(),
            ),
        )
        .await
        .unwrap();
    let existing = existing_result.structured_content.unwrap();
    assert_eq!(existing["linked"][0]["id"], stored.id);

    let atomic_result = client
        .call_tool(
            CallToolRequestParams::new("memory_create_interpretation").with_arguments(
                serde_json::json!({
                    "body": "the brass key opens the workshop",
                    "new_observation_body": "a brass key is on the desk"
                })
                .as_object()
                .cloned()
                .unwrap(),
            ),
        )
        .await
        .unwrap();
    let atomic = atomic_result.structured_content.unwrap();
    assert_eq!(atomic["linked"].as_array().unwrap().len(), 1);
    assert_eq!(atomic["linked"][0]["body"], "a brass key is on the desk");

    client.cancel().await.unwrap();
    cancellation.cancel();
    server.await.unwrap();
}
