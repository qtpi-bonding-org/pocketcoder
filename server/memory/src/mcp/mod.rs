// SPDX-License-Identifier: AGPL-3.0-or-later

mod tools;

use axum::{
    Json, Router,
    extract::Request,
    http::StatusCode,
    middleware::{self, Next},
    response::{IntoResponse, Response},
    routing::get,
};
use rmcp::transport::streamable_http_server::{
    StreamableHttpServerConfig, StreamableHttpService, session::local::LocalSessionManager,
};
use serde::Serialize;
use tokio_util::sync::CancellationToken;

use crate::{identity::decode_identity, service::MemoryService};

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    canonical_store: bool,
    semantic_search: bool,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

pub fn router(service: MemoryService, cancellation: CancellationToken) -> Router {
    let health_service = service.clone();
    let mcp_service = StreamableHttpService::new(
        move || Ok(tools::MemoryMcp::new(service.clone())),
        LocalSessionManager::default().into(),
        StreamableHttpServerConfig::default()
            .with_legacy_session_mode(false)
            .with_json_response(true)
            .with_cancellation_token(cancellation),
    );
    let protected_mcp = Router::new()
        .nest_service("/mcp", mcp_service)
        .layer(middleware::from_fn(require_identity));

    Router::new()
        .route(
            "/health",
            get(move || {
                let service = health_service.clone();
                async move { health(&service) }
            }),
        )
        .merge(protected_mcp)
}

fn health(service: &MemoryService) -> Json<HealthResponse> {
    let semantic_search = service.semantic_search_available();
    Json(HealthResponse {
        status: if semantic_search {
            "ready"
        } else {
            "degraded_fts_only"
        },
        canonical_store: true,
        semantic_search,
    })
}

async fn require_identity(mut request: Request, next: Next) -> Response {
    if request.headers().contains_key("origin") {
        tracing::warn!("browser-origin request rejected");
        return (
            StatusCode::FORBIDDEN,
            Json(ErrorResponse {
                error: "browser origins are not accepted on the private MCP endpoint".to_owned(),
            }),
        )
            .into_response();
    }
    match decode_identity(request.headers()) {
        Ok(identity) => {
            request.extensions_mut().insert(identity);
            next.run(request).await
        }
        Err(error) => {
            tracing::warn!(error = %error, "MCP identity header rejected");
            (
                StatusCode::BAD_REQUEST,
                Json(ErrorResponse {
                    error: error.to_string(),
                }),
            )
                .into_response()
        }
    }
}
