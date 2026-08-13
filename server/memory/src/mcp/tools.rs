// SPDX-License-Identifier: AGPL-3.0-or-later

use axum::http::request::Parts;
use rmcp::{
    ErrorData as McpError, Json, RoleServer, ServerHandler,
    handler::server::{router::tool::ToolRouter, wrapper::Parameters},
    model::{Implementation, ServerCapabilities, ServerInfo},
    service::RequestContext,
    tool, tool_handler, tool_router,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use crate::{
    AgentIdentity, MemoryError, MemoryKind, MemoryRecord,
    service::{MemoryService, MemoryWithLinks, SearchMatch},
};

#[derive(Clone)]
pub(super) struct MemoryMcp {
    service: MemoryService,
    #[allow(dead_code)]
    tool_router: ToolRouter<Self>,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct CreateObservationArgs {
    body: String,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct CreateInterpretationArgs {
    body: String,
    #[serde(default)]
    observation_ids: Vec<String>,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct UpdateArgs {
    id: String,
    body: String,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct IdArgs {
    id: String,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct LinkArgs {
    interpretation_id: String,
    observation_ids: Vec<String>,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct GetArgs {
    kind: MemoryKind,
    id: String,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct ListArgs {
    kind: MemoryKind,
    author_profile_id: Option<String>,
    limit: Option<u32>,
    offset: Option<u32>,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct SearchArgs {
    query: String,
    kind: Option<MemoryKind>,
    author_profile_id: Option<String>,
    top_k: Option<u32>,
    deep_recall: Option<bool>,
    lambda: Option<f64>,
    debug: Option<bool>,
}

#[derive(Debug, Serialize, JsonSchema)]
struct MutationResult {
    ok: bool,
}

#[derive(Debug, Serialize, JsonSchema)]
struct SearchResult {
    mode: &'static str,
    matches: Vec<SearchMatch>,
}

impl MemoryMcp {
    pub(super) fn new(service: MemoryService) -> Self {
        Self {
            service,
            tool_router: Self::tool_router(),
        }
    }
}

#[tool_router]
impl MemoryMcp {
    #[tool(
        name = "memory_create_observation",
        description = "Create a mutable observation authored by the active agent profile. Identity is supplied automatically."
    )]
    async fn create_observation(
        &self,
        Parameters(args): Parameters<CreateObservationArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MemoryRecord>, McpError> {
        let identity = identity(&context)?;
        self.service
            .create_observation(&identity, args.body)
            .await
            .map(Json)
            .map_err(map_error)
    }

    #[tool(
        name = "memory_create_interpretation",
        description = "Create a mutable agent-authored interpretation, optionally linked to existing observations. The service performs no interpretation itself."
    )]
    async fn create_interpretation(
        &self,
        Parameters(args): Parameters<CreateInterpretationArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MemoryRecord>, McpError> {
        let identity = identity(&context)?;
        self.service
            .create_interpretation(&identity, args.body, &args.observation_ids)
            .await
            .map(Json)
            .map_err(map_error)
    }

    #[tool(
        name = "memory_update_observation",
        description = "Replace an observation body by ID."
    )]
    async fn update_observation(
        &self,
        Parameters(args): Parameters<UpdateArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MemoryRecord>, McpError> {
        self.update(MemoryKind::Observation, args, &context).await
    }

    #[tool(
        name = "memory_update_interpretation",
        description = "Replace an interpretation body by ID."
    )]
    async fn update_interpretation(
        &self,
        Parameters(args): Parameters<UpdateArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MemoryRecord>, McpError> {
        self.update(MemoryKind::Interpretation, args, &context)
            .await
    }

    #[tool(
        name = "memory_delete_observation",
        description = "Delete an observation; its join rows cascade."
    )]
    async fn delete_observation(
        &self,
        Parameters(args): Parameters<IdArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MutationResult>, McpError> {
        self.delete(MemoryKind::Observation, &args.id, &context)
            .await
    }

    #[tool(
        name = "memory_delete_interpretation",
        description = "Delete an interpretation; its join rows cascade."
    )]
    async fn delete_interpretation(
        &self,
        Parameters(args): Parameters<IdArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MutationResult>, McpError> {
        self.delete(MemoryKind::Interpretation, &args.id, &context)
            .await
    }

    #[tool(
        name = "memory_link",
        description = "Idempotently link an interpretation to one or more observations without assigning semantic relation types."
    )]
    async fn link(
        &self,
        Parameters(args): Parameters<LinkArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MutationResult>, McpError> {
        let identity = identity(&context)?;
        self.service
            .link(&identity, &args.interpretation_id, &args.observation_ids)
            .await
            .map(|()| Json(MutationResult { ok: true }))
            .map_err(map_error)
    }

    #[tool(
        name = "memory_unlink",
        description = "Idempotently remove ordinary interpretation-observation links."
    )]
    async fn unlink(
        &self,
        Parameters(args): Parameters<LinkArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MutationResult>, McpError> {
        let identity = identity(&context)?;
        self.service
            .unlink(&identity, &args.interpretation_id, &args.observation_ids)
            .await
            .map(|()| Json(MutationResult { ok: true }))
            .map_err(map_error)
    }

    #[tool(
        name = "memory_get",
        description = "Fetch one memory plus all directly linked memories."
    )]
    async fn get(
        &self,
        Parameters(args): Parameters<GetArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MemoryWithLinks>, McpError> {
        let identity = identity(&context)?;
        self.service
            .get(&identity, args.kind, &args.id)
            .await
            .map(Json)
            .map_err(map_error)
    }

    #[tool(
        name = "memory_list",
        description = "List memories by kind and optional author profile inside the active account."
    )]
    async fn list(
        &self,
        Parameters(args): Parameters<ListArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<Vec<MemoryRecord>>, McpError> {
        let identity = identity(&context)?;
        self.service
            .list(
                &identity,
                args.kind,
                args.author_profile_id,
                args.limit.unwrap_or(50),
                args.offset.unwrap_or(0),
            )
            .await
            .map(Json)
            .map_err(map_error)
    }

    #[tool(
        name = "memory_search",
        description = "Recall observations and interpretations. Hybrid semantic retrieval is local; when unavailable the response explicitly reports FTS-only degraded mode."
    )]
    async fn search(
        &self,
        Parameters(args): Parameters<SearchArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<SearchResult>, McpError> {
        let identity = identity(&context)?;
        let _debug = args.debug.unwrap_or(false);
        self.service
            .search_fts_only(
                &identity,
                &args.query,
                args.kind,
                args.author_profile_id.as_deref(),
                args.top_k.unwrap_or(10),
                args.deep_recall.unwrap_or(false),
                args.lambda.unwrap_or(0.05),
            )
            .await
            .map(|matches| {
                Json(SearchResult {
                    mode: "degraded_fts_only",
                    matches,
                })
            })
            .map_err(map_error)
    }

    async fn update(
        &self,
        kind: MemoryKind,
        args: UpdateArgs,
        context: &RequestContext<RoleServer>,
    ) -> Result<Json<MemoryRecord>, McpError> {
        let identity = identity(context)?;
        self.service
            .update(&identity, kind, &args.id, args.body)
            .await
            .map(Json)
            .map_err(map_error)
    }

    async fn delete(
        &self,
        kind: MemoryKind,
        id: &str,
        context: &RequestContext<RoleServer>,
    ) -> Result<Json<MutationResult>, McpError> {
        let identity = identity(context)?;
        self.service
            .delete(&identity, kind, id)
            .await
            .map(|()| Json(MutationResult { ok: true }))
            .map_err(map_error)
    }
}

#[tool_handler]
impl ServerHandler for MemoryMcp {
    fn get_info(&self) -> ServerInfo {
        ServerInfo::new(ServerCapabilities::builder().enable_tools().build())
            .with_server_info(Implementation::from_build_env())
            .with_instructions(
                "The active agent writes mutable observations and interpretations. The service stores and retrieves them; it does not reason, summarize, or determine truth."
                    .to_owned(),
            )
    }
}

fn identity(context: &RequestContext<RoleServer>) -> Result<AgentIdentity, McpError> {
    context
        .extensions
        .get::<Parts>()
        .and_then(|parts| parts.extensions.get::<AgentIdentity>())
        .cloned()
        .ok_or_else(|| McpError::invalid_params("memory identity context is missing", None))
}

fn map_error(error: MemoryError) -> McpError {
    match error {
        MemoryError::InvalidInput(message) | MemoryError::InvalidIdentity(message) => {
            McpError::invalid_params(message, None)
        }
        MemoryError::NotFound { kind, id } => {
            McpError::invalid_params(format!("{kind} {id} was not found"), None)
        }
        MemoryError::CrossAccountLink => McpError::invalid_params(
            "observation and interpretation must belong to the active account",
            None,
        ),
        internal => {
            tracing::error!(error = %internal, "memory tool failed");
            McpError::internal_error("memory service failed", None)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Repository;

    #[tokio::test]
    async fn tool_schemas_do_not_ask_agents_for_identity() {
        let repository = Repository::open_in_memory().await.unwrap();
        let server = MemoryMcp::new(MemoryService::new(repository));
        let tools = server.tool_router.list_all();
        let names = tools
            .iter()
            .map(|tool| tool.name.as_ref())
            .collect::<Vec<_>>();
        assert_eq!(names.len(), 11);
        assert!(names.contains(&"memory_create_observation"));
        assert!(names.contains(&"memory_search"));

        for tool in tools {
            let schema = serde_json::to_string(&tool.input_schema).unwrap();
            assert!(!schema.contains("account_id"));
            assert!(!schema.contains("agent_profile_id"));
            assert!(!schema.contains("agent_name"));
        }
    }
}
