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
    domain::TimestampFilter,
    service::{InterpretationObservation, MemoryService, MemoryWithLinks, SearchMatch, SearchMode},
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
    existing_observation_id: Option<String>,
    new_observation_body: Option<String>,
    #[serde(default)]
    additional_observation_ids: Vec<String>,
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
struct ListArgs {
    kind: MemoryKind,
    author_profile_id: Option<String>,
    #[serde(flatten)]
    timestamps: TimestampFilter,
    limit: Option<u32>,
    offset: Option<u32>,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct SearchArgs {
    query: String,
    kind: Option<MemoryKind>,
    author_profile_id: Option<String>,
    #[serde(flatten)]
    timestamps: TimestampFilter,
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
    mode: SearchMode,
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
        description = "Create an agent-authored interpretation with at least one observation. Provide exactly one starting source: existing_observation_id, or new_observation_body to create an observation atomically. additional_observation_ids are optional and all links are equal."
    )]
    async fn create_interpretation(
        &self,
        Parameters(args): Parameters<CreateInterpretationArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MemoryWithLinks>, McpError> {
        let identity = identity(&context)?;
        let observation = match (args.existing_observation_id, args.new_observation_body) {
            (Some(id), None) if !id.trim().is_empty() => {
                InterpretationObservation::ExistingObservation(id)
            }
            (None, Some(body)) if !body.trim().is_empty() => {
                InterpretationObservation::NewObservation(body)
            }
            _ => {
                return Err(McpError::invalid_params(
                    "provide exactly one of existing_observation_id or new_observation_body",
                    None,
                ));
            }
        };
        self.service
            .create_interpretation(
                &identity,
                args.body,
                observation,
                &args.additional_observation_ids,
            )
            .await
            .map(Json)
            .map_err(map_error)
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
        description = "Idempotently remove interpretation-observation links without allowing an interpretation to lose its final observation."
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
        name = "memory_get_observation",
        description = "Fetch one observation and all interpretations linked to it."
    )]
    async fn get_observation(
        &self,
        Parameters(args): Parameters<IdArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MemoryWithLinks>, McpError> {
        let identity = identity(&context)?;
        self.service
            .get(&identity, MemoryKind::Observation, &args.id)
            .await
            .map(Json)
            .map_err(map_error)
    }

    #[tool(
        name = "memory_get_interpretation",
        description = "Fetch one interpretation and all observations linked to it."
    )]
    async fn get_interpretation(
        &self,
        Parameters(args): Parameters<IdArgs>,
        context: RequestContext<RoleServer>,
    ) -> Result<Json<MemoryWithLinks>, McpError> {
        let identity = identity(&context)?;
        self.service
            .get(&identity, MemoryKind::Interpretation, &args.id)
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
                args.timestamps,
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
        self.service
            .search(
                &identity,
                &args.query,
                args.kind,
                args.author_profile_id.as_deref(),
                args.timestamps,
                args.top_k.unwrap_or(10),
                args.deep_recall.unwrap_or(false),
                args.lambda.unwrap_or(0.05),
                args.debug.unwrap_or(false),
            )
            .await
            .map(|output| {
                Json(SearchResult {
                    mode: output.mode,
                    matches: output.matches,
                })
            })
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
        assert_eq!(names.len(), 8);
        assert!(names.contains(&"memory_create_observation"));
        assert!(names.contains(&"memory_create_interpretation"));
        assert!(names.contains(&"memory_link"));
        assert!(names.contains(&"memory_unlink"));
        assert!(names.contains(&"memory_get_observation"));
        assert!(names.contains(&"memory_get_interpretation"));
        assert!(names.contains(&"memory_list"));
        assert!(names.contains(&"memory_search"));
        assert!(!names.iter().any(|name| name.contains("update")));
        assert!(!names.iter().any(|name| name.contains("delete")));

        for tool in tools {
            let schema = serde_json::to_string(&tool.input_schema).unwrap();
            assert!(!schema.contains("account_id"));
            assert!(!schema.contains("agent_profile_id"));
            assert!(!schema.contains("agent_name"));
        }
    }
}
