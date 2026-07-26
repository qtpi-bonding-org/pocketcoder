# Spike: which agent config is live over ACP vs. requires a container restart

**Goal:** answer, with source-level evidence, which of Goose's configuration
knobs (provider, model, system prompt, MCP servers, permission mode,
per-tool permission policy, API keys) can be changed per-session over ACP
with no restart, versus which are only read from `config.yaml`/env vars at
process boot. This feeds the design for a PocketBase/Flutter "reconfigure
the agent" UI — restart-based knobs are expensive and clunky to expose live;
live-ACP knobs are cheap and should be the default place new config UI
writes to.

**Method:** cloned Goose at the exact version c2 is pinned to —
`aaif-goose/goose` tag `v1.43.0` (matches the digest in
`services/goose/Dockerfile`) — into `.independent_repos/goose_reference`
(gitignored, not committed) and traced the ACP server implementation
(`crates/goose/src/acp/`) directly, cross-checked against what PocketCoder's
Go coordinator (`services/pocketbase/internal/agent/coordinator/`) actually
sends today.

Two protocol layers exist: the standard `agent-client-protocol` crate (wire
methods like `session/new`, `session/set_mode`, `session/set_config_option`)
and a Goose-specific layer of custom `_goose/unstable/*` JSON-RPC methods
(defined in `crates/goose-sdk-types/src/custom_requests.rs`). Both are real,
implemented, live mechanisms — "custom/unstable" doesn't mean unsupported,
it means Goose-specific rather than part of the neutral ACP spec.

## The split

| # | Knob | Verdict | Mechanism | Restart needed? |
|---|---|---|---|---|
| 1 | **Provider** | 🟢 LIVE | `session/new`'s `meta["provider"]` (session start), or standard `session/set_config_option{config_id:"provider"}` (mid-session) | No |
| 2 | **Model** | 🟢 LIVE | Standard `session/set_config_option{config_id:"model"}` mid-session (`on_set_model`) | No |
| 3 | **System prompt / instructions** | 🟢 LIVE (mechanism exists, **not wired up in PocketCoder today**) | Custom `_goose/unstable/session/system-prompt/set` (`SetSessionSystemPromptRequest`), callable any time against an existing session | No |
| 4 | **MCP servers / extensions** | 🟢 LIVE, both at creation and mid-conversation | `session/new`'s standard `mcp_servers` field + Goose's `meta["enabledExtensions"]` at creation; custom `_goose/unstable/session/extensions/add`/`remove` mid-session | No |
| 5 | **Permission MODE** (auto/approve/chat/smart-approve) | 🟢 LIVE | Standard `session/set_mode` (`SetSessionModeRequest`) — already used by PocketCoder today (`coordinator/profile.go`'s `GlobalConfigApplier`) | No |
| 6 | **Per-tool permission policy** (allow/ask/deny per tool name) | 🟡 LIVE but **process-wide, not per-session**, and **exact-name match only** (no glob/prefix) | Custom `_goose/unstable/tools/permissions/set` (`SetToolPermissionsRequest`) → `PermissionManager`, a process-wide singleton backed by `~/.config/goose/permission.yaml` inside the container | No — but scoping is a real constraint, see below |
| 7 | **API keys / provider credentials** | 🔴 BOOT-ONLY in practice | Goose has a live `_goose/unstable/providers/config/save` path, but `Config::get_secret` checks env vars *first* — since PocketCoder supplies keys as env vars (`keys.env`) at container boot, those always win over anything set live. The live path is dead weight for our deployment unless we stop setting env vars. | Yes (as currently deployed) |

## What this means for the "reconfigure agent from Flutter" design

- **Provider, model, system prompt, MCP servers, and permission mode should
  all move off the file+restart pipeline (`goose_config.go`'s
  `config.yaml` render + `restartContainer`) and onto live ACP calls,
  issued per-chat at session-start or mid-conversation.** This is strictly
  better: no restart storm on every edit, and (for provider/model/prompt)
  it becomes genuinely per-session/per-chat instead of one global default
  row (`poco_configs.is_default`) shared by everyone.
- **Item 3 is a concrete, small bug worth fixing regardless of the bigger
  redesign**: PocketCoder already computes `SessionProfile.Instructions`
  (`internal/api/profile.go`) but never sends it — the coordinator's
  comment says instructions are "delivered by the render pipeline +
  restart," which the code no longer actually does (`prompts`/
  `poco_configs.system_prompt` are not read by `goose_config.go` at all —
  see the earlier audit, `audit-status/c1-go-backend.md`). Wiring
  `_goose/unstable/session/system-prompt/set` fixes a currently-silent gap,
  not just a nice-to-have.
- **Item 6 (per-tool policy) is the one genuine open design question.**
  `SetToolPermissionsRequest` has no `session_id` — it's process-wide. If
  two different chats (belonging to different users, or just different
  agents) want different tool policies, one goose process can't hold both
  live at once via this mechanism. Options to resolve before designing the
  UI:
  - Accept process-wide scope for now (one tool-policy set for the whole
    deployment) — matches today's reality (`tool_permissions` is already
    effectively global, `poco_config` scoping is unused in practice) and
    is the simplest thing that ships.
  - Run one goose process per user/agent (bigger infra change, likely
    overkill for a single/family-scale deployment).
  - Re-apply the live call every time the *active* session's owner
    differs from the last one that set it (cheap, but racy under
    concurrent sessions from different users — needs a decision on
    whether that's actually a real scenario for this deployment's scale).
- **Item 7 stays boot-only.** Any "add your API key" UI still needs to
  write `provider_keys` → render `keys.env` → restart goose. That's fine —
  it's inherently rare (you add a provider once, not every chat) and
  process-wide secrets genuinely belong in env vars, not live RPCs.
- **Net result**: the restart-based `config.yaml` pipeline shrinks to just
  "which provider credentials exist in this container" — exactly the
  hypothesis from the earlier discussion, confirmed by source, with one
  caveat (tool-policy scoping) to decide on explicitly rather than by
  accretion.

## Evidence / file references (all in `.independent_repos/goose_reference`, not committed)

- `crates/goose/src/acp/server/new_session.rs` — `session/new` handling,
  `meta["provider"]`/`meta["enabledExtensions"]` parsing
  (`resolve_provider_and_model`, `build_enabled_extensions_data`)
- `crates/goose/src/acp/server/dispatch.rs` — `session/set_config_option`
  and `session/set_mode` switchboard
- `crates/goose/src/acp/server/manage_sessions.rs` — system-prompt
  override/extend
- `crates/goose/src/acp/server/extensions.rs` — mid-session add/remove
  extension
- `crates/goose/src/acp/server/tools.rs` — `SetToolPermissionsRequest`
  dispatch
- `crates/goose/src/acp/server/providers.rs` — live provider-secret save
- `crates/goose-sdk-types/src/custom_requests.rs` — all `_goose/unstable/*`
  method names and request/response struct shapes
- `crates/goose/src/config/permission.rs`,
  `crates/goose/src/permission/permission_inspector.rs` — the actual
  tool-permission decision path (`PermissionManager`, process-wide,
  exact-name match)
- `crates/goose/src/config/base.rs` — secret precedence (env var beats
  keyring/secrets.yaml)
- PocketCoder side: `services/pocketbase/internal/api/profile.go`,
  `services/pocketbase/internal/agent/coordinator/profile.go`,
  `services/pocketbase/internal/agent/coordinator/run.go` — confirms
  `Instructions`/model/provider are computed but not currently sent on
  `session/new`; only `Mode` is actually applied post-create today.

## Next step

Not yet designed: the actual schema/UI cleanup (deleting the dead
`ai_agents`/`llm_keys`-era collections+screens, building real Flutter
screens against `poco_configs`/`harness_models`/`provider_keys`/`prompts`,
deciding the item-6 scoping question above). This doc is only the
"what's technically possible" input to that design — see the parent
conversation for where that design lands next.
