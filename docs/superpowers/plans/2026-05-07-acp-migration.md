# ACP Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the OpenCode-specific interface wiring with ACP so any ACP-compliant agent CLI (opencode, gemini, claude-code) can serve as Poco, making the main agent fully swappable.

**Architecture:** Interface spawns the configured agent CLI as a child process and communicates via ACP over stdio. Interface is the ACP `ClientSideConnection` (owns all execution — files, terminals, permissions). The agent CLI is the ACP `AgentSideConnection` (reasons and requests). The `opencode` container is removed — the agent CLI runs as a subprocess inside the Interface container. All execution is proxied to the sandbox via the existing Rust proxy.

**Tech Stack:** Bun/TypeScript (`@agentclientprotocol/sdk`, `pocketbase`), Go (PocketBase hooks), Dart (Flutter model regeneration)

**Specs:**
- `docs/superpowers/specs/2026-05-07-acp-agent-agnosticism-design.md`
- `docs/superpowers/specs/2026-05-07-pocketbase-acp-schema-design.md`
- `docs/superpowers/specs/2026-05-07-pocketbase-config-layer-schema-design.md`

---

## File Map

### New files
- `services/pocketbase/pb_migrations/1748000100_acp_schema.go` — schema migration
- `services/pocketbase/internal/hooks/harness_auth.go` — OAuth state hook *(deferred — see Out of Scope)*
- `services/interface/src/sandbox-proxy.ts` — file + terminal proxying to sandbox
- `services/interface/src/acp-client.ts` — ACP `ClientSideConnection` implementation
- `services/interface/src/command-pump.ts` — PocketBase subscriptions → ACP calls
- `services/interface/src/event-pump.ts` — ACP callbacks → PocketBase writes
- `services/interface/src/poco-process.ts` — agent CLI subprocess lifecycle
- `services/interface/src/index.ts` — rewrites existing orchestration entry point

### Modified files
- `services/pocketbase/internal/hooks/llm.go` — rename collection + container
- `services/pocketbase/internal/hooks/mcp.go` — rename container, add `acp_transport`
- `services/pocketbase/internal/hooks/tool_permissions.go` — rename collection refs
- `services/pocketbase/internal/hooks/agents.go` — rename collection refs
- `services/pocketbase/internal/hooks/helpers.go` — rename container constants
- `services/interface/package.json` — swap SDK
- `services/interface/Dockerfile` — add agent CLI installs
- `docker-compose.yml` — remove `opencode` service, update `interface`

### Deleted files
- `services/opencode/` — entire directory (agent CLI now runs inside Interface)

### Generated (run pipeline after schema tasks)
- `client/packages/pocketcoder_flutter/assets/pb_schema.json`
- `client/packages/pocketcoder_flutter/lib/domain/models/` — Dart models

---

## Task 1: PocketBase schema migration — config layer

**Files:**
- Create: `services/pocketbase/pb_migrations/1748000100_acp_schema.go`

- [ ] **Step 1: Write the migration file**

```go
package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		addFields := func(c *core.Collection, fields ...core.Field) {
			for _, f := range fields {
				if existing := c.Fields.GetByName(f.GetName()); existing == nil {
					c.Fields.Add(f)
				}
			}
		}
		getOrCreate := func(id, name string) (*core.Collection, error) {
			if c, _ := app.FindCollectionByNameOrId(name); c != nil {
				return c, nil
			}
			c := core.NewBaseCollection(name)
			c.Id = id
			return c, nil
		}
		authOnly := ptr("@request.auth.id != ''")

		// ── harnesses ─────────────────────────────────────────────────────────
		harnesses, _ := getOrCreate("pc_harnesses", "harnesses")
		addFields(harnesses,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "cli_id", Required: true},
			&core.TextField{Name: "version"},
			&core.TextField{Name: "description"},
			&core.SelectField{Name: "acp_transport", Required: true,
				Values: []string{"websocket", "stdio", "http"}},
		)
		harnesses.ListRule = authOnly
		harnesses.ViewRule = authOnly
		harnesses.Indexes = []string{
			"CREATE UNIQUE INDEX idx_harnesses_cli_id ON harnesses (cli_id)",
		}
		if err := app.Save(harnesses); err != nil { return err }

		// ── models ────────────────────────────────────────────────────────────
		models, _ := getOrCreate("pc_models", "models")
		addFields(models,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "display_name"},
			&core.TextField{Name: "provider", Required: true},
			&core.NumberField{Name: "context_window"},
			&core.TextField{Name: "description"},
		)
		models.ListRule = authOnly
		models.ViewRule = authOnly
		if err := app.Save(models); err != nil { return err }

		// ── harness_models (join) ─────────────────────────────────────────────
		hm, _ := getOrCreate("pc_harness_models", "harness_models")
		addFields(hm,
			&core.RelationField{Name: "harness", CollectionId: harnesses.Id, Required: true, MaxSelect: 1},
			&core.RelationField{Name: "model", CollectionId: models.Id, Required: true, MaxSelect: 1},
			&core.TextField{Name: "harness_model_id", Required: true},
			&core.BoolField{Name: "is_default"},
		)
		hm.ListRule = authOnly
		hm.ViewRule = authOnly
		hm.Indexes = []string{
			"CREATE UNIQUE INDEX idx_harness_models_pair ON harness_models (harness, model)",
		}
		if err := app.Save(hm); err != nil { return err }

		// ── provider_keys (was llm_keys) ──────────────────────────────────────
		pk, _ := getOrCreate("pc_provider_keys", "provider_keys")
		addFields(pk,
			&core.RelationField{Name: "user", CollectionId: "_pb_users_auth_", Required: true, MaxSelect: 1},
			&core.TextField{Name: "provider", Required: true},
			&core.JSONField{Name: "env_vars"},
		)
		pk.ListRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		pk.ViewRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		pk.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		pk.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		pk.DeleteRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		pk.Indexes = []string{
			"CREATE UNIQUE INDEX idx_provider_keys_user_provider ON provider_keys (user, provider)",
		}
		if err := app.Save(pk); err != nil { return err }

		// ── harness_auth ──────────────────────────────────────────────────────
		ha, _ := getOrCreate("pc_harness_auth", "harness_auth")
		addFields(ha,
			&core.RelationField{Name: "user", CollectionId: "_pb_users_auth_", Required: true, MaxSelect: 1},
			&core.RelationField{Name: "harness", CollectionId: harnesses.Id, Required: true, MaxSelect: 1},
			&core.SelectField{Name: "auth_type", Required: true, Values: []string{"api_key", "oauth"}},
			&core.SelectField{Name: "status", Required: true,
				Values: []string{"unauthenticated", "pending", "authenticated", "expired"}},
			&core.TextField{Name: "auth_url"},
			&core.DateField{Name: "expires_at"},
		)
		ha.ListRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		ha.ViewRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		ha.CreateRule = authOnly
		ha.UpdateRule = ptr("user = @request.auth.id || @request.auth.role = 'admin'")
		ha.Indexes = []string{
			"CREATE UNIQUE INDEX idx_harness_auth_user_harness ON harness_auth (user, harness)",
		}
		if err := app.Save(ha); err != nil { return err }

		// ── prompts (was ai_prompts) ───────────────────────────────────────────
		prompts, _ := getOrCreate("pc_prompts", "prompts")
		addFields(prompts,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "body", Required: true},
		)
		prompts.ListRule = authOnly
		prompts.ViewRule = authOnly
		if err := app.Save(prompts); err != nil { return err }

		// ── skills ────────────────────────────────────────────────────────────
		skills, _ := getOrCreate("pc_skills", "skills")
		addFields(skills,
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "description"},
			&core.TextField{Name: "body", Required: true},
			&core.TextField{Name: "tags"},
			&core.BoolField{Name: "active"},
		)
		skills.ListRule = authOnly
		skills.ViewRule = authOnly
		skills.Indexes = []string{
			"CREATE UNIQUE INDEX idx_skills_name ON skills (name)",
		}
		if err := app.Save(skills); err != nil { return err }

		// ── poco_configs ──────────────────────────────────────────────────────
		pc, _ := getOrCreate("pc_poco_configs", "poco_configs")
		addFields(pc,
			&core.TextField{Name: "name", Required: true},
			&core.RelationField{Name: "harness_model", CollectionId: hm.Id, Required: true, MaxSelect: 1},
			&core.RelationField{Name: "system_prompt", CollectionId: prompts.Id, MaxSelect: 1},
			&core.JSONField{Name: "workspace_folders"},
			&core.JSONField{Name: "acp_mcp_servers"},
			&core.BoolField{Name: "is_default"},
		)
		pc.ListRule = authOnly
		pc.ViewRule = authOnly
		pc.Indexes = []string{
			"CREATE UNIQUE INDEX idx_poco_configs_name ON poco_configs (name)",
		}
		if err := app.Save(pc); err != nil { return err }

		// ── sandbox_configs ───────────────────────────────────────────────────
		sc, _ := getOrCreate("pc_sandbox_configs", "sandbox_configs")
		addFields(sc,
			&core.TextField{Name: "name", Required: true},
			&core.RelationField{Name: "harness_model", CollectionId: hm.Id, Required: true, MaxSelect: 1},
			&core.RelationField{Name: "system_prompt", CollectionId: prompts.Id, MaxSelect: 1},
		)
		sc.ListRule = authOnly
		sc.ViewRule = authOnly
		sc.Indexes = []string{
			"CREATE UNIQUE INDEX idx_sandbox_configs_name ON sandbox_configs (name)",
		}
		if err := app.Save(sc); err != nil { return err }

		return nil
	}, func(app core.App) error {
		for _, name := range []string{
			"sandbox_configs", "poco_configs", "skills", "prompts",
			"harness_auth", "provider_keys", "harness_models", "models", "harnesses",
		} {
			if c, _ := app.FindCollectionByNameOrId(name); c != nil {
				if err := app.Delete(c); err != nil { return err }
			}
		}
		return nil
	})
}
```

- [ ] **Step 2: Run migration locally**

```bash
docker compose build pocketbase
docker compose up -d pocketbase
# Watch logs for migration success
docker compose logs -f pocketbase | grep -E "migration|error|Error" | head -20
```

Expected: `[migrations] applied 1748000100_acp_schema`

- [ ] **Step 3: Commit**

```bash
git add services/pocketbase/pb_migrations/1748000100_acp_schema.go
git commit -m "feat(schema): add config layer collections — harnesses, models, harness_models, provider_keys, harness_auth, prompts, skills, poco_configs, sandbox_configs"
```

---

## Task 2: PocketBase schema migration — ACP layer

**Files:**
- Modify: `services/pocketbase/pb_migrations/1748000100_acp_schema.go` (add to existing migration)

Add the ACP layer collection changes to the same migration file, before the `return nil` in the up function:

- [ ] **Step 1: Add ACP layer changes to the migration**

Append inside the `migrations.Register` up function, after `sandbox_configs` save:

```go
		// ── chats: add ACP fields, add poco_config relation ───────────────────
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil { return err }
		addFields(chats,
			&core.TextField{Name: "acp_session_id"},
			&core.SelectField{Name: "current_role", Values: []string{"user", "assistant"}},
			&core.RelationField{Name: "poco_config", CollectionId: pc.Id, MaxSelect: 1},
			&core.RelationField{Name: "harness_model_override", CollectionId: hm.Id, MaxSelect: 1},
		)
		// description field already exists; acp_session_id replaces ai_engine_session_id
		chats.Indexes = append(chats.Indexes,
			"CREATE INDEX idx_chats_acp_session_id ON chats (acp_session_id)",
		)
		if err := app.Save(chats); err != nil { return err }

		// ── messages: rename parts→content, add usage/cost/acp_status ────────
		messages, err := app.FindCollectionByNameOrId("messages")
		if err != nil { return err }
		addFields(messages,
			&core.JSONField{Name: "content"},
			&core.SelectField{Name: "acp_status",
				Values: []string{"streaming", "completed", "failed", "cancelled"}},
			&core.JSONField{Name: "usage"},
			&core.JSONField{Name: "cost"},
		)
		if err := app.Save(messages); err != nil { return err }

		// ── permissions: ACP fields ───────────────────────────────────────────
		perms, err := app.FindCollectionByNameOrId("permissions")
		if err != nil { return err }
		addFields(perms,
			&core.TextField{Name: "acp_request_id"},
			&core.TextField{Name: "acp_session_id"},
			&core.TextField{Name: "tool_name"},
			&core.JSONField{Name: "tool_input"},
			&core.TextField{Name: "description"},
			&core.JSONField{Name: "permission_options"},
			&core.SelectField{Name: "acp_status",
				Values: []string{"pending", "allow_once", "allow_always", "deny"}},
			&core.TextField{Name: "selected_option_id"},
			&core.TextField{Name: "acp_message_id"},
			&core.TextField{Name: "tool_call_id"},
		)
		perms.Indexes = append(perms.Indexes,
			"CREATE UNIQUE INDEX idx_permissions_acp_request_id ON permissions (acp_request_id)",
		)
		if err := app.Save(perms); err != nil { return err }

		// ── acp_terminals (replaces sandbox_agents) ───────────────────────────
		at, _ := getOrCreate("pc_acp_terminals", "acp_terminals")
		addFields(at,
			&core.TextField{Name: "acp_terminal_id", Required: true},
			&core.TextField{Name: "acp_session_id", Required: true},
			&core.TextField{Name: "name"},
			&core.TextField{Name: "cwd"},
			&core.NumberField{Name: "exit_code"},
			&core.SelectField{Name: "status", Required: true,
				Values: []string{"running", "exited", "killed"}},
			&core.RelationField{Name: "chat", CollectionId: chats.Id, MaxSelect: 1},
			&core.NumberField{Name: "tmux_window_id"},
		)
		at.ListRule = authOnly
		at.ViewRule = authOnly
		at.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		at.UpdateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		at.Indexes = []string{
			"CREATE UNIQUE INDEX idx_acp_terminals_terminal_id ON acp_terminals (acp_terminal_id)",
			"CREATE INDEX idx_acp_terminals_session_id ON acp_terminals (acp_session_id)",
		}
		if err := app.Save(at); err != nil { return err }

		// ── tool_permissions: add poco_config + sandbox_config, keep agent nullable
		toolPerms, err := app.FindCollectionByNameOrId("tool_permissions")
		if err != nil { return err }
		addFields(toolPerms,
			&core.RelationField{Name: "poco_config", CollectionId: pc.Id, MaxSelect: 1},
			&core.RelationField{Name: "sandbox_config", CollectionId: sc.Id, MaxSelect: 1},
		)
		if err := app.Save(toolPerms); err != nil { return err }

		// ── cron_jobs: add poco_config relation alongside existing agent relation
		cronJobs, err := app.FindCollectionByNameOrId("cron_jobs")
		if err != nil { return err }
		addFields(cronJobs,
			&core.RelationField{Name: "poco_config", CollectionId: pc.Id, MaxSelect: 1},
		)
		if err := app.Save(cronJobs); err != nil { return err }

		// ── mcp_servers: add acp_transport field ─────────────────────────────
		mcpServers, err := app.FindCollectionByNameOrId("mcp_servers")
		if err != nil { return err }
		addFields(mcpServers,
			&core.SelectField{Name: "acp_transport",
				Values: []string{"http", "sse", "stdio"}},
		)
		if err := app.Save(mcpServers); err != nil { return err }
```

- [ ] **Step 2: Re-run migration**

```bash
docker compose down pocketbase
docker compose up -d pocketbase
docker compose logs -f pocketbase | grep -E "migration|error" | head -20
```

Expected: migration applies cleanly, no errors.

- [ ] **Step 3: Commit**

```bash
git add services/pocketbase/pb_migrations/1748000100_acp_schema.go
git commit -m "feat(schema): add ACP layer fields to chats, messages, permissions; add acp_terminals, mcp_servers.acp_transport"
```

---

## Task 3: Update Go hooks — rename container and collection references

**Files:**
- Modify: `services/pocketbase/internal/hooks/helpers.go`
- Modify: `services/pocketbase/internal/hooks/llm.go`
- Modify: `services/pocketbase/internal/hooks/mcp.go`
- Modify: `services/pocketbase/internal/hooks/tool_permissions.go`
- Modify: `services/pocketbase/internal/hooks/agents.go`

- [ ] **Step 1: Update container name in helpers.go**

```bash
grep -n "OpenCodeContainer\|pocketcoder-opencode" services/pocketbase/internal/hooks/helpers.go
```

Replace the constant (exact line may differ):
```go
// Before
const OpenCodeContainer = "pocketcoder-opencode"

// After — interface container now hosts the agent CLI
const PocoContainer = "pocketcoder-interface"
```

Then replace all usages across hook files:
```bash
sed -i '' 's/OpenCodeContainer/PocoContainer/g' \
  services/pocketbase/internal/hooks/llm.go \
  services/pocketbase/internal/hooks/mcp.go \
  services/pocketbase/internal/hooks/tool_permissions.go
```

- [ ] **Step 2: Update llm.go — rename collection reference**

```bash
grep -n "llm_keys" services/pocketbase/internal/hooks/llm.go
```

Replace in `RegisterLlmHooks`:
```go
// Before
app.OnRecordAfterCreateSuccess("llm_keys").BindFunc(...)
app.OnRecordAfterUpdateSuccess("llm_keys").BindFunc(...)
app.OnRecordAfterDeleteSuccess("llm_keys").BindFunc(...)
records, err := app.FindAllRecords("llm_keys")

// After
app.OnRecordAfterCreateSuccess("provider_keys").BindFunc(...)
app.OnRecordAfterUpdateSuccess("provider_keys").BindFunc(...)
app.OnRecordAfterDeleteSuccess("provider_keys").BindFunc(...)
records, err := app.FindAllRecords("provider_keys")
```

The env file paths (`llmEnvPath`, `llmEnvPathShared`) and rendering logic are unchanged.

- [ ] **Step 3: Update mcp.go — rename container and notify target**

```bash
grep -n "opencode\|OpenCode" services/pocketbase/internal/hooks/mcp.go
```

Replace the `restartContainer` call and any notification references:
```go
// Before
restartContainer("pocketcoder-opencode", 30*time.Second)

// After
restartContainer(PocoContainer, 30*time.Second)
```

If `notifyPoco()` or similar sends an HTTP notification to `http://opencode:3000/...`, update the URL to use the interface service's internal endpoint or remove if no longer needed (the interface now gets updates via PocketBase subscription).

- [ ] **Step 4: Update tool_permissions.go — query poco_configs**

```bash
grep -n "ai_agents\|ai_prompts\|ai_models" services/pocketbase/internal/hooks/tool_permissions.go
```

The hook rebuilds the agent config when tool_permissions change. Update it to query `poco_configs` instead of `ai_agents`:
```go
// Before
agents, err := app.FindAllRecords("ai_agents")

// After — rebuild only poco_configs (sandbox_configs don't drive container restarts)
configs, err := app.FindAllRecords("poco_configs")
```

Update the permission block assembly to expand `poco_config` and `sandbox_config` relations on tool_permissions records:
```go
// Before
records, _ := app.FindAllRecords("tool_permissions",
  dbx.HashExp{"active": true},
)

// After — filter by poco_config presence for Poco permission rebuild
records, _ := app.FindRecordsByFilter("tool_permissions",
  "active = true && poco_config != ''", "", 0, 0,
)
```

- [ ] **Step 5: Update agents.go — rename collection refs**

```bash
grep -n "ai_agents\|ai_prompts\|ai_models" services/pocketbase/internal/hooks/agents.go
```

Replace collection names:
```go
// Before
app.OnRecordAfterUpdateSuccess("ai_agents").BindFunc(...)
app.OnRecordAfterUpdateSuccess("ai_prompts").BindFunc(...)
app.OnRecordAfterUpdateSuccess("ai_models").BindFunc(...)
records, _ := app.FindAllRecords("ai_agents")

// After
app.OnRecordAfterUpdateSuccess("poco_configs").BindFunc(...)
app.OnRecordAfterUpdateSuccess("prompts").BindFunc(...)
app.OnRecordAfterUpdateSuccess("harness_models").BindFunc(...)
records, _ := app.FindAllRecords("poco_configs")
```

In the bundle builder, replace `record.GetString("identifier")` (from ai_models) with the expanded harness_model lookup:
```go
// Before
modelId := modelRecord.GetString("identifier")

// After — expand harness_model to get harness-specific ID
hmRecord, _ := app.FindRecordById("harness_models", config.GetString("harness_model"))
modelId := hmRecord.GetString("harness_model_id")
```

- [ ] **Step 6: Build and verify**

```bash
cd services/pocketbase && go build ./...
```

Expected: compiles with no errors.

- [ ] **Step 7: Commit**

```bash
git add services/pocketbase/internal/hooks/
git commit -m "refactor(hooks): rename container refs opencode→poco, collections llm_keys→provider_keys, ai_agents→poco_configs/sandbox_configs"
```

---

## Task 4: Export schema and regenerate Dart models

Follow the pipeline from CLAUDE.md:

- [ ] **Step 1: Rebuild and start PocketBase**

```bash
docker compose build pocketbase
docker compose up -d pocketbase
sleep 5
```

- [ ] **Step 2: Export schema**

```bash
scripts/export_schema.sh
```

Expected: `client/packages/pocketcoder_flutter/assets/pb_schema.json` updated with new collections.

- [ ] **Step 3: Generate Dart models**

```bash
cd client/packages/pocketcoder_flutter
python3 scripts/generate_models.py
```

- [ ] **Step 4: Generate freezed code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: no errors, new model files for `harnesses`, `models`, `harness_models`, `provider_keys`, `harness_auth`, `prompts`, `skills`, `poco_configs`, `sandbox_configs`, `acp_terminals`.

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/assets/pb_schema.json \
        client/packages/pocketcoder_flutter/lib/domain/models/
git commit -m "chore(flutter): regenerate models from updated ACP+config schema"
```

---

## Task 5: Swap Interface SDK and scaffold new file structure

**Files:**
- Modify: `services/interface/package.json`
- Create: `services/interface/src/sandbox-proxy.ts`
- Create: `services/interface/src/acp-client.ts`
- Create: `services/interface/src/command-pump.ts`
- Create: `services/interface/src/event-pump.ts`
- Create: `services/interface/src/poco-process.ts`

- [ ] **Step 1: Update package.json**

```json
{
    "name": "pocketcoder-interface",
    "version": "2.0.0",
    "description": "ACP bridge between PocketBase and the Poco agent CLI",
    "main": "src/index.ts",
    "type": "module",
    "scripts": {
        "start": "bun src/index.ts",
        "dev": "bun --watch src/index.ts",
        "test": "bun test"
    },
    "dependencies": {
        "@agentclientprotocol/sdk": "^0.21.0",
        "pocketbase": "^0.26.8"
    },
    "devDependencies": {
        "bun-types": "^1.3.10",
        "@types/node": "^25.3.3"
    }
}
```

- [ ] **Step 2: Install dependencies**

```bash
cd services/interface && bun install
```

Expected: `node_modules/@agentclientprotocol` present, `@opencode-ai/sdk` absent.

- [ ] **Step 3: Verify ACP SDK exports**

```bash
cd services/interface
bun -e "import { ClientSideConnection } from '@agentclientprotocol/sdk'; console.log(typeof ClientSideConnection)"
```

Expected: `function`

- [ ] **Step 4: Commit**

```bash
git add services/interface/package.json services/interface/bun.lockb
git commit -m "chore(interface): swap @opencode-ai/sdk for @agentclientprotocol/sdk"
```

---

## Task 6: Implement sandbox proxy module

**Files:**
- Create: `services/interface/src/sandbox-proxy.ts`
- Create: `services/interface/src/sandbox-proxy.test.ts`

The sandbox proxy translates ACP file/terminal callbacks into calls to the sandbox Rust proxy and shared filesystem.

- [ ] **Step 1: Write failing tests**

```typescript
// services/interface/src/sandbox-proxy.test.ts
import { describe, test, expect, mock } from 'bun:test';
import { SandboxProxy } from './sandbox-proxy';

describe('SandboxProxy', () => {
  test('readTextFile reads from workspace volume', async () => {
    const proxy = new SandboxProxy({
      workspacePath: '/tmp/test-workspace',
      proxyUrl: 'http://localhost:3001',
    });
    // write a test file
    await Bun.write('/tmp/test-workspace/hello.txt', 'hello world');
    const result = await proxy.readTextFile('/tmp/test-workspace/hello.txt');
    expect(result.content).toBe('hello world');
  });

  test('writeTextFile writes to workspace volume', async () => {
    const proxy = new SandboxProxy({
      workspacePath: '/tmp/test-workspace',
      proxyUrl: 'http://localhost:3001',
    });
    await proxy.writeTextFile('/tmp/test-workspace/out.txt', 'written');
    const content = await Bun.file('/tmp/test-workspace/out.txt').text();
    expect(content).toBe('written');
  });

  test('createTerminal calls sandbox proxy HTTP endpoint', async () => {
    const fetchMock = mock(() =>
      Promise.resolve(new Response(JSON.stringify({ id: 'term-1', name: 'main' })))
    );
    global.fetch = fetchMock as any;
    const proxy = new SandboxProxy({
      workspacePath: '/tmp/test-workspace',
      proxyUrl: 'http://sandbox:3001',
    });
    const terminal = await proxy.createTerminal({ name: 'main', cwd: '/workspace' });
    expect(terminal.id).toBe('term-1');
    expect(fetchMock).toHaveBeenCalledWith(
      'http://sandbox:3001/terminals',
      expect.objectContaining({ method: 'POST' })
    );
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd services/interface && bun test src/sandbox-proxy.test.ts
```

Expected: FAIL — `Cannot find module './sandbox-proxy'`

- [ ] **Step 3: Implement the module**

```typescript
// services/interface/src/sandbox-proxy.ts
import fs from 'fs/promises';
import path from 'path';

interface SandboxProxyConfig {
  workspacePath: string;
  proxyUrl: string; // pocketcoder-proxy base URL e.g. http://sandbox:3001
}

export interface Terminal {
  id: string;
  name?: string;
  cwd?: string;
}

export class SandboxProxy {
  constructor(private config: SandboxProxyConfig) {}

  async readTextFile(filePath: string): Promise<{ content: string }> {
    const content = await fs.readFile(filePath, 'utf-8');
    return { content };
  }

  async writeTextFile(filePath: string, content: string): Promise<void> {
    await fs.mkdir(path.dirname(filePath), { recursive: true });
    await fs.writeFile(filePath, content, 'utf-8');
  }

  async createTerminal(opts: { name?: string; cwd?: string }): Promise<Terminal> {
    const res = await fetch(`${this.config.proxyUrl}/terminals`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(opts),
    });
    if (!res.ok) throw new Error(`createTerminal failed: ${res.status}`);
    return res.json() as Promise<Terminal>;
  }

  async writeTerminalInput(terminalId: string, data: string): Promise<void> {
    await fetch(`${this.config.proxyUrl}/terminals/${terminalId}/input`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data }),
    });
  }

  async killTerminal(terminalId: string): Promise<void> {
    await fetch(`${this.config.proxyUrl}/terminals/${terminalId}`, {
      method: 'DELETE',
    });
  }

  async waitForTerminalExit(terminalId: string): Promise<{ exitCode: number }> {
    const res = await fetch(`${this.config.proxyUrl}/terminals/${terminalId}/wait`);
    if (!res.ok) throw new Error(`waitForTerminalExit failed: ${res.status}`);
    return res.json() as Promise<{ exitCode: number }>;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd services/interface && bun test src/sandbox-proxy.test.ts
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add services/interface/src/sandbox-proxy.ts services/interface/src/sandbox-proxy.test.ts
git commit -m "feat(interface): add SandboxProxy — file read/write and terminal proxying to sandbox"
```

---

## Task 7: Implement Poco process manager

**Files:**
- Create: `services/interface/src/poco-process.ts`
- Create: `services/interface/src/poco-process.test.ts`

Manages the agent CLI child process lifecycle and exposes its stdio streams for ACP.

- [ ] **Step 1: Write failing tests**

```typescript
// services/interface/src/poco-process.test.ts
import { describe, test, expect } from 'bun:test';
import { PocoProcess } from './poco-process';

describe('PocoProcess', () => {
  test('spawns agent process and exposes streams', async () => {
    const proc = new PocoProcess({ agentCmd: 'cat' }); // cat echoes stdin → stdout
    await proc.start();
    expect(proc.stdin).toBeDefined();
    expect(proc.stdout).toBeDefined();
    await proc.stop();
  });

  test('resolves exit promise when process exits', async () => {
    const proc = new PocoProcess({ agentCmd: 'echo hello' });
    await proc.start();
    const code = await proc.exited;
    expect(typeof code).toBe('number');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd services/interface && bun test src/poco-process.test.ts
```

Expected: FAIL — `Cannot find module './poco-process'`

- [ ] **Step 3: Implement**

```typescript
// services/interface/src/poco-process.ts
import { spawn, type Subprocess } from 'bun';

interface PocoProcessConfig {
  agentCmd: string; // e.g. "opencode acp" or "gemini"
  env?: Record<string, string>;
}

export class PocoProcess {
  private proc?: Subprocess;
  stdin!: WritableStream<Uint8Array>;
  stdout!: ReadableStream<Uint8Array>;
  exited!: Promise<number>;

  constructor(private config: PocoProcessConfig) {}

  async start(): Promise<void> {
    const [cmd, ...args] = this.config.agentCmd.split(' ');
    this.proc = spawn([cmd, ...args], {
      stdin: 'pipe',
      stdout: 'pipe',
      stderr: 'inherit',
      env: { ...process.env, ...this.config.env },
    });
    this.stdin = this.proc.stdin;
    this.stdout = this.proc.stdout;
    this.exited = this.proc.exited;
  }

  async stop(): Promise<void> {
    this.proc?.kill();
    await this.proc?.exited;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd services/interface && bun test src/poco-process.test.ts
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add services/interface/src/poco-process.ts services/interface/src/poco-process.test.ts
git commit -m "feat(interface): add PocoProcess — agent CLI child process lifecycle manager"
```

---

## Task 8: Implement ACP ClientSideConnection

**Files:**
- Create: `services/interface/src/acp-client.ts`
- Create: `services/interface/src/acp-client.test.ts`

**Note:** Before implementing, verify the exact ACP SDK transport API:
```bash
cd services/interface
bun -e "
import sdk from '@agentclientprotocol/sdk';
console.log(Object.keys(sdk));
"
```
Read the output to confirm `ClientSideConnection` constructor signature. The implementation below follows the SDK's stream-based transport pattern.

- [ ] **Step 1: Write failing tests**

```typescript
// services/interface/src/acp-client.test.ts
import { describe, test, expect, mock, beforeEach } from 'bun:test';
import { buildAcpClient } from './acp-client';
import type { SandboxProxy } from './sandbox-proxy';
import type PocketBase from 'pocketbase';

const mockPb = {
  collection: mock(() => ({
    create: mock(() => Promise.resolve({ id: 'perm-1' })),
    update: mock(() => Promise.resolve({})),
    getFirstListItem: mock(() => Promise.resolve({ selected_option_id: 'allow_once' })),
  })),
} as unknown as PocketBase;

const mockProxy = {
  readTextFile: mock(() => Promise.resolve({ content: 'hello' })),
  writeTextFile: mock(() => Promise.resolve()),
  createTerminal: mock(() => Promise.resolve({ id: 'term-1' })),
  killTerminal: mock(() => Promise.resolve()),
  waitForTerminalExit: mock(() => Promise.resolve({ exitCode: 0 })),
} as unknown as SandboxProxy;

describe('buildAcpClient', () => {
  test('readTextFile proxies to sandbox', async () => {
    const client = buildAcpClient({ pb: mockPb, proxy: mockProxy });
    const result = await client.readTextFile({ path: '/workspace/foo.ts' });
    expect(result.content).toBe('hello');
    expect(mockProxy.readTextFile).toHaveBeenCalledWith('/workspace/foo.ts');
  });

  test('writeTextFile proxies to sandbox', async () => {
    const client = buildAcpClient({ pb: mockPb, proxy: mockProxy });
    await client.writeTextFile({ path: '/workspace/foo.ts', content: 'bar' });
    expect(mockProxy.writeTextFile).toHaveBeenCalledWith('/workspace/foo.ts', 'bar');
  });

  test('requestPermission creates PocketBase record and waits', async () => {
    const client = buildAcpClient({ pb: mockPb, proxy: mockProxy });
    const result = await client.requestPermission({
      sessionId: 'sess-1',
      id: 'req-1',
      toolName: 'bash',
      input: { command: 'rm -rf /' },
      description: 'Run bash command',
      permissionOptions: [
        { id: 'allow_once', kind: 'allow_once', title: 'Allow once' },
        { id: 'deny', kind: 'deny', title: 'Deny' },
      ],
    });
    expect(mockPb.collection).toHaveBeenCalledWith('permissions');
    expect(result.selectedPermissionOption.permissionOptionId).toBe('allow_once');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd services/interface && bun test src/acp-client.test.ts
```

Expected: FAIL — `Cannot find module './acp-client'`

- [ ] **Step 3: Implement**

```typescript
// services/interface/src/acp-client.ts
import type PocketBase from 'pocketbase';
import type { SandboxProxy } from './sandbox-proxy';

// Types mirrored from @agentclientprotocol/sdk — import from SDK once transport API is confirmed
interface PermissionOption {
  id: string;
  kind: string;
  title: string;
  description?: string;
}

interface RequestPermissionRequest {
  sessionId: string;
  id: string;
  toolName: string;
  input: unknown;
  description?: string;
  permissionOptions?: PermissionOption[];
}

interface AcpClientImpl {
  readTextFile(req: { path: string }): Promise<{ content: string }>;
  writeTextFile(req: { path: string; content: string }): Promise<void>;
  createTerminal(req: { name?: string; cwd?: string }): Promise<{ terminal: { id: string; name?: string; cwd?: string } }>;
  terminalOutput(terminalId: string, onData: (data: string) => void): Promise<void>;
  releaseTerminal(terminalId: string): Promise<void>;
  waitForTerminalExit(terminalId: string): Promise<{ exitCode: number }>;
  killTerminal(terminalId: string): Promise<void>;
  sessionUpdate(update: unknown): Promise<void>;
  requestPermission(req: RequestPermissionRequest): Promise<{ selectedPermissionOption: { permissionOptionId: string } }>;
}

interface AcpClientDeps {
  pb: PocketBase;
  proxy: SandboxProxy;
  chatId?: string; // set per-session, updated by command pump
}

export function buildAcpClient(deps: AcpClientDeps): AcpClientImpl {
  return {
    async readTextFile({ path }) {
      return deps.proxy.readTextFile(path);
    },

    async writeTextFile({ path, content }) {
      return deps.proxy.writeTextFile(path, content);
    },

    async createTerminal({ name, cwd } = {}) {
      const terminal = await deps.proxy.createTerminal({ name, cwd });
      if (deps.chatId) {
        await deps.pb.collection('acp_terminals').create({
          acp_terminal_id: terminal.id,
          name,
          cwd,
          status: 'running',
          chat: deps.chatId,
        });
      }
      return { terminal };
    },

    async terminalOutput(_terminalId, _onData) {
      // Terminal output streaming handled by poco-process stdout via ACP SDK
    },

    async releaseTerminal(terminalId) {
      await deps.proxy.killTerminal(terminalId);
    },

    async waitForTerminalExit(terminalId) {
      const result = await deps.proxy.waitForTerminalExit(terminalId);
      await deps.pb.collection('acp_terminals').getFirstListItem(
        `acp_terminal_id = "${terminalId}"`
      ).then(rec =>
        deps.pb.collection('acp_terminals').update(rec.id, {
          exit_code: result.exitCode,
          status: 'exited',
        })
      ).catch(() => {}); // terminal may not be tracked if no chatId
      return result;
    },

    async killTerminal(terminalId) {
      await deps.proxy.killTerminal(terminalId);
      await deps.pb.collection('acp_terminals').getFirstListItem(
        `acp_terminal_id = "${terminalId}"`
      ).then(rec =>
        deps.pb.collection('acp_terminals').update(rec.id, { status: 'killed' })
      ).catch(() => {});
    },

    async sessionUpdate(_update) {
      // Handled by event-pump which registers this callback with more context
    },

    async requestPermission(req) {
      // 1. Write permission request to PocketBase
      await deps.pb.collection('permissions').create({
        acp_request_id: req.id,
        acp_session_id: req.sessionId,
        tool_name: req.toolName,
        tool_input: req.input,
        description: req.description ?? '',
        permission_options: req.permissionOptions ?? [],
        acp_status: 'pending',
        chat: deps.chatId,
      });

      // 2. Poll until user responds (Flutter sets selected_option_id + acp_status)
      const pollIntervalMs = 1000;
      const timeoutMs = 5 * 60 * 1000; // 5 min
      const start = Date.now();
      while (Date.now() - start < timeoutMs) {
        const rec = await deps.pb.collection('permissions').getFirstListItem(
          `acp_request_id = "${req.id}"`
        );
        if (rec.acp_status !== 'pending' && rec.selected_option_id) {
          return { selectedPermissionOption: { permissionOptionId: rec.selected_option_id } };
        }
        await Bun.sleep(pollIntervalMs);
      }
      // Timeout — deny by default
      return { selectedPermissionOption: { permissionOptionId: 'deny' } };
    },
  };
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd services/interface && bun test src/acp-client.test.ts
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add services/interface/src/acp-client.ts services/interface/src/acp-client.test.ts
git commit -m "feat(interface): add ACP ClientSideConnection implementation — file/terminal proxy, permission gating"
```

---

## Task 9: Implement event pump (ACP sessionUpdate → PocketBase)

**Files:**
- Create: `services/interface/src/event-pump.ts`
- Create: `services/interface/src/event-pump.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// services/interface/src/event-pump.test.ts
import { describe, test, expect, mock } from 'bun:test';
import { EventPump } from './event-pump';

const mockPb = () => ({
  collection: mock((name: string) => ({
    create: mock(() => Promise.resolve({ id: 'msg-1' })),
    update: mock(() => Promise.resolve({})),
    getFirstListItem: mock(() => Promise.resolve({ id: 'msg-1', content: [] })),
  })),
});

describe('EventPump', () => {
  test('sessionUpdate with text content creates/updates message', async () => {
    const pb = mockPb() as any;
    const pump = new EventPump({ pb, chatId: 'chat-1', sessionId: 'sess-1' });

    await pump.handleSessionUpdate({
      type: 'content',
      messageId: 'msg-abc',
      role: 'assistant',
      content: [{ type: 'text', text: 'Hello world' }],
      status: 'streaming',
    });

    expect(pb.collection).toHaveBeenCalledWith('messages');
  });

  test('sessionUpdate with completed status sets acp_status', async () => {
    const pb = mockPb() as any;
    const pump = new EventPump({ pb, chatId: 'chat-1', sessionId: 'sess-1' });

    await pump.handleSessionUpdate({
      type: 'status',
      messageId: 'msg-abc',
      status: 'completed',
    });

    const updateMock = pb.collection('messages').update;
    expect(updateMock).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({ acp_status: 'completed' })
    );
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd services/interface && bun test src/event-pump.test.ts
```

Expected: FAIL

- [ ] **Step 3: Implement**

```typescript
// services/interface/src/event-pump.ts
import type PocketBase from 'pocketbase';

interface EventPumpConfig {
  pb: PocketBase;
  chatId: string;
  sessionId: string;
}

interface SessionUpdateEvent {
  type: 'content' | 'status' | 'usage';
  messageId?: string;
  role?: 'user' | 'assistant';
  content?: unknown[];
  status?: 'streaming' | 'completed' | 'failed' | 'cancelled';
  usage?: { inputTokens?: number; outputTokens?: number; cacheReadTokens?: number; cacheWriteTokens?: number };
  cost?: { inputCost?: number; outputCost?: number; totalCost?: number };
}

export class EventPump {
  // messageId → PocketBase record id
  private messageIdMap = new Map<string, string>();

  constructor(private config: EventPumpConfig) {}

  async handleSessionUpdate(update: SessionUpdateEvent): Promise<void> {
    const { pb, chatId } = this.config;

    if (update.type === 'content' && update.messageId) {
      const existing = this.messageIdMap.get(update.messageId);
      if (existing) {
        await pb.collection('messages').update(existing, {
          content: update.content,
          acp_status: update.status ?? 'streaming',
        });
      } else {
        const rec = await pb.collection('messages').create({
          chat: chatId,
          role: update.role ?? 'assistant',
          content: update.content ?? [],
          acp_status: update.status ?? 'streaming',
        });
        this.messageIdMap.set(update.messageId, rec.id);
      }
    }

    if (update.type === 'status' && update.messageId) {
      const recId = this.messageIdMap.get(update.messageId);
      if (recId) {
        await pb.collection('messages').update(recId, {
          acp_status: update.status,
        });
      }
    }

    if (update.type === 'usage' && update.messageId) {
      const recId = this.messageIdMap.get(update.messageId);
      if (recId) {
        await pb.collection('messages').update(recId, {
          usage: update.usage,
          cost: update.cost,
        });
      }
    }
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd services/interface && bun test src/event-pump.test.ts
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add services/interface/src/event-pump.ts services/interface/src/event-pump.test.ts
git commit -m "feat(interface): add EventPump — ACP sessionUpdate callbacks to PocketBase messages"
```

---

## Task 10: Implement command pump (PocketBase → ACP)

**Files:**
- Create: `services/interface/src/command-pump.ts`
- Create: `services/interface/src/command-pump.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// services/interface/src/command-pump.test.ts
import { describe, test, expect, mock } from 'bun:test';
import { CommandPump } from './command-pump';

const makeAcpMock = () => ({
  newSession: mock(() => Promise.resolve({ sessionId: 'sess-new' })),
  resumeSession: mock(() => Promise.resolve({ sessionId: 'sess-existing' })),
  prompt: mock(() => Promise.resolve({})),
  setSessionConfigOption: mock(() => Promise.resolve({})),
});

describe('CommandPump', () => {
  test('new user message with no session creates ACP session and prompts', async () => {
    const acp = makeAcpMock();
    const pump = new CommandPump({ acp: acp as any });

    await pump.handleNewMessage({
      messageId: 'pb-msg-1',
      chatId: 'chat-1',
      text: 'Hello Poco',
      acpSessionId: null,
      mcpServers: [{ type: 'http', url: 'http://sandbox:9888/mcp' }],
      workspaceFolders: [{ uri: 'file:///workspace' }],
    });

    expect(acp.newSession).toHaveBeenCalledWith(
      expect.objectContaining({ mcpServers: expect.any(Array) })
    );
    expect(acp.prompt).toHaveBeenCalledWith(
      expect.objectContaining({ content: expect.any(Array) })
    );
  });

  test('message on existing session resumes and prompts', async () => {
    const acp = makeAcpMock();
    const pump = new CommandPump({ acp: acp as any });

    await pump.handleNewMessage({
      messageId: 'pb-msg-2',
      chatId: 'chat-1',
      text: 'Follow up',
      acpSessionId: 'sess-existing',
      mcpServers: [],
      workspaceFolders: [],
    });

    expect(acp.newSession).not.toHaveBeenCalled();
    expect(acp.prompt).toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd services/interface && bun test src/command-pump.test.ts
```

Expected: FAIL

- [ ] **Step 3: Implement**

```typescript
// services/interface/src/command-pump.ts

interface McpServer {
  type: 'http' | 'sse' | 'stdio';
  url: string;
}

interface WorkspaceFolder {
  uri: string;
}

interface NewMessageParams {
  messageId: string;
  chatId: string;
  text: string;
  acpSessionId: string | null;
  mcpServers: McpServer[];
  workspaceFolders: WorkspaceFolder[];
}

interface AcpAgent {
  newSession(params: { mcpServers: McpServer[]; workspaceFolders: WorkspaceFolder[] }): Promise<{ sessionId: string }>;
  resumeSession(params: { sessionId: string }): Promise<{ sessionId: string }>;
  prompt(params: { sessionId: string; content: Array<{ type: string; text: string }> }): Promise<void>;
  setSessionConfigOption(params: { sessionId: string; key: string; value: string }): Promise<void>;
}

export class CommandPump {
  constructor(private config: { acp: AcpAgent }) {}

  async handleNewMessage(params: NewMessageParams): Promise<string> {
    const { acp } = this.config;
    let sessionId = params.acpSessionId;

    if (!sessionId) {
      const result = await acp.newSession({
        mcpServers: params.mcpServers,
        workspaceFolders: params.workspaceFolders,
      });
      sessionId = result.sessionId;
    } else {
      await acp.resumeSession({ sessionId });
    }

    await acp.prompt({
      sessionId,
      content: [{ type: 'text', text: params.text }],
    });

    return sessionId;
  }

  async handleModelChange(params: { sessionId: string; model: string }): Promise<void> {
    await this.config.acp.setSessionConfigOption({
      sessionId: params.sessionId,
      key: 'model',
      value: params.model,
    });
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd services/interface && bun test src/command-pump.test.ts
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add services/interface/src/command-pump.ts services/interface/src/command-pump.test.ts
git commit -m "feat(interface): add CommandPump — PocketBase subscriptions to ACP session/prompt calls"
```

---

## Task 11: Rewrite interface entry point

**Files:**
- Modify: `services/interface/src/index.ts`

Wires all modules together: PocketBase auth, Poco process spawn, ACP connection, command/event pump subscriptions, health endpoint.

- [ ] **Step 1: Verify ACP SDK connection API**

```bash
cd services/interface
bun -e "
import { ClientSideConnection } from '@agentclientprotocol/sdk';
const fn = ClientSideConnection.toString().slice(0, 200);
console.log(fn);
"
```

Note the constructor signature — it takes a transport (stream pair or connection object). Adjust the connection setup below to match.

- [ ] **Step 2: Rewrite index.ts**

```typescript
// services/interface/src/index.ts
import PocketBase from 'pocketbase';
import { ClientSideConnection } from '@agentclientprotocol/sdk';
import { SandboxProxy } from './sandbox-proxy';
import { PocoProcess } from './poco-process';
import { buildAcpClient } from './acp-client';
import { EventPump } from './event-pump';
import { CommandPump } from './command-pump';

const POCKETBASE_URL = process.env.POCKETBASE_URL ?? 'http://pocketbase:8090';
const SANDBOX_PROXY_URL = process.env.SANDBOX_PROXY_URL ?? 'http://sandbox:3001';
const WORKSPACE_PATH = process.env.WORKSPACE_PATH ?? '/workspace';
const POCO_AGENT_CMD = process.env.POCO_AGENT_CMD ?? 'opencode acp';
const AGENT_EMAIL = process.env.AGENT_EMAIL!;
const AGENT_PASSWORD = process.env.AGENT_PASSWORD!;
const HEALTH_PORT = parseInt(process.env.HEALTH_PORT ?? '8080');

async function main() {
  // ── PocketBase auth ────────────────────────────────────────────────────────
  const pb = new PocketBase(POCKETBASE_URL);
  await pb.collection('users').authWithPassword(AGENT_EMAIL, AGENT_PASSWORD);
  // Refresh auth token every 6 days (token lifetime is 7 days)
  setInterval(() => pb.collection('users').authRefresh(), 6 * 24 * 60 * 60 * 1000);

  // ── Sandbox proxy ─────────────────────────────────────────────────────────
  const proxy = new SandboxProxy({ workspacePath: WORKSPACE_PATH, proxyUrl: SANDBOX_PROXY_URL });

  // ── Spawn Poco agent CLI process ──────────────────────────────────────────
  const poco = new PocoProcess({ agentCmd: POCO_AGENT_CMD });
  await poco.start();
  poco.exited.then(code => {
    console.error(`[poco] agent process exited with code ${code}, restarting...`);
    process.exit(1); // Let Docker restart the service
  });

  // ── ACP client implementation (shared, chatId set per-session) ────────────
  const acpClientImpl = buildAcpClient({ pb, proxy });

  // ── ACP ClientSideConnection ──────────────────────────────────────────────
  // Note: transport API depends on SDK version — adjust if constructor differs
  const connection = new ClientSideConnection(
    { readable: poco.stdout, writable: poco.stdin },
    acpClientImpl
  );

  // Expose typed ACP agent interface from the connection
  const acpAgent = connection.agent;

  // ── Session → chat cache ──────────────────────────────────────────────────
  const sessionToChat = new Map<string, string>();

  // ── Override sessionUpdate to route to EventPump ──────────────────────────
  const eventPumps = new Map<string, EventPump>();
  acpClientImpl.sessionUpdate = async (update: unknown) => {
    const u = update as { sessionId?: string };
    const chatId = u.sessionId ? sessionToChat.get(u.sessionId) : undefined;
    if (!chatId) return;
    let pump = eventPumps.get(chatId);
    if (!pump) {
      pump = new EventPump({ pb, chatId, sessionId: u.sessionId! });
      eventPumps.set(chatId, pump);
    }
    await pump.handleSessionUpdate(update as any);
  };

  // ── Command pump — subscribe to PocketBase messages collection ────────────
  const commandPump = new CommandPump({ acp: acpAgent });

  await pb.collection('messages').subscribe('*', async (e) => {
    if (e.action !== 'create') return;
    const msg = e.record;
    // Only process user messages that haven't been sent to Poco yet
    if (msg.role !== 'user' || msg.acp_session_id) return;

    const chat = await pb.collection('chats').getOne(msg.chat, { expand: 'poco_config.harness_model' });
    const pocoConfig = chat.expand?.poco_config;
    const mcpServers = pocoConfig?.acp_mcp_servers ?? [{ type: 'http', url: 'http://sandbox:9888/mcp' }];
    const workspaceFolders = pocoConfig?.workspace_folders ?? [{ uri: 'file:///workspace' }];

    const sessionId = await commandPump.handleNewMessage({
      messageId: msg.id,
      chatId: msg.chat,
      text: msg.content?.[0]?.text ?? '',
      acpSessionId: chat.acp_session_id ?? null,
      mcpServers,
      workspaceFolders,
    });

    // Persist session ID if new
    if (!chat.acp_session_id) {
      await pb.collection('chats').update(msg.chat, { acp_session_id: sessionId });
      sessionToChat.set(sessionId, msg.chat);
    }
  });

  // ── Command pump — subscribe to permissions for user responses ─────────────
  await pb.collection('permissions').subscribe('*', async (e) => {
    if (e.action !== 'update') return;
    const perm = e.record;
    if (!perm.selected_option_id || perm.acp_status === 'pending') return;
    // Permission polling in acp-client.ts handles this — no extra action needed
  });

  // ── Command pump — subscribe to harness_model_override for model changes ──
  await pb.collection('chats').subscribe('*', async (e) => {
    if (e.action !== 'update') return;
    const chat = e.record;
    if (!chat.harness_model_override || !chat.acp_session_id) return;
    const hm = await pb.collection('harness_models').getOne(chat.harness_model_override, { expand: 'model' });
    await commandPump.handleModelChange({
      sessionId: chat.acp_session_id,
      model: hm.harness_model_id,
    });
  });

  // ── Health endpoint ───────────────────────────────────────────────────────
  Bun.serve({
    port: HEALTH_PORT,
    fetch(req) {
      const url = new URL(req.url);
      if (url.pathname === '/healthz') {
        const healthy = !!acpAgent;
        return new Response(JSON.stringify({ status: healthy ? 'ok' : 'degraded' }), {
          status: healthy ? 200 : 503,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return new Response('not found', { status: 404 });
    },
  });

  console.log(`[interface] started — agent: ${POCO_AGENT_CMD}, health: :${HEALTH_PORT}`);
}

main().catch(err => {
  console.error('[interface] fatal:', err);
  process.exit(1);
});
```

- [ ] **Step 3: Run all tests to confirm nothing broken**

```bash
cd services/interface && bun test
```

Expected: all tests from tasks 6–10 pass.

- [ ] **Step 4: Commit**

```bash
git add services/interface/src/index.ts
git commit -m "feat(interface): rewrite entry point — ACP ClientSideConnection wiring PocketBase↔Poco"
```

---

## Task 12: Update Interface Dockerfile to install agent CLIs

**Files:**
- Modify: `services/interface/Dockerfile`

- [ ] **Step 1: Update Dockerfile**

```dockerfile
FROM oven/bun:1

WORKDIR /app

# Install agent CLIs based on POCO_AGENT build arg
ARG POCO_AGENT=opencode
RUN if [ "$POCO_AGENT" = "opencode" ]; then \
      bun install -g opencode-ai@1.2.15; \
    elif [ "$POCO_AGENT" = "claude-code" ]; then \
      npm install -g @zed-industries/claude-code-acp; \
    elif [ "$POCO_AGENT" = "gemini" ]; then \
      npm install -g @google/gemini-cli; \
    fi

COPY package.json bun.lockb ./
RUN bun install --frozen-lockfile

COPY src/ ./src/

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s \
  CMD wget -qO- http://localhost:8080/healthz || exit 1

CMD ["bun", "src/index.ts"]
```

- [ ] **Step 2: Build to verify**

```bash
docker compose build interface
```

Expected: builds without error.

- [ ] **Step 3: Commit**

```bash
git add services/interface/Dockerfile
git commit -m "feat(interface): install configured agent CLI (POCO_AGENT) at build time"
```

---

## Task 13: Update Docker Compose — remove opencode, update interface

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Apply Docker Compose changes**

Make these changes to `docker-compose.yml`:

1. **Delete the entire `opencode:` service block**

2. **Update the `interface:` service** — replace the existing block with:

```yaml
  interface:
    build:
      context: .
      dockerfile: services/interface/Dockerfile
      args:
        POCO_AGENT: ${POCO_AGENT:-opencode}
    container_name: pocketcoder-interface
    restart: unless-stopped
    environment:
      POCKETBASE_URL: http://pocketbase:8090
      SANDBOX_PROXY_URL: http://sandbox:3001
      WORKSPACE_PATH: /workspace
      POCO_AGENT_CMD: ${POCO_AGENT_CMD:-opencode acp}
      AGENT_EMAIL: ${AGENT_EMAIL}
      AGENT_PASSWORD: ${AGENT_PASSWORD}
      HEALTH_PORT: 8080
    volumes:
      - opencode_workspace:/workspace
      - llm_keys:/llm_keys:ro
      - opencode.json:/app/agent-config.json:ro
    networks:
      - pocketcoder-pocketbase-sdk
      - pocketcoder-control
    depends_on:
      pocketbase:
        condition: service_healthy
      sandbox:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8080/healthz"]
      interval: 10s
      timeout: 5s
      start-period: 30s
      retries: 3
```

3. **Remove `pocketcoder-opencode-sdk` network** from all services that reference it (replace with `pocketcoder-pocketbase-sdk` where needed)

4. **Add `.env` entries** to `.env.example`:
```
POCO_AGENT=opencode
POCO_AGENT_CMD=opencode acp
```

- [ ] **Step 2: Verify compose config is valid**

```bash
docker compose config --quiet
```

Expected: exits 0 with no errors.

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml .env.example
git commit -m "feat(compose): remove opencode service, update interface to spawn agent CLI in-process"
```

---

## Task 14: Integration smoke test

Bring up the full stack and verify end-to-end message flow.

- [ ] **Step 1: Build all services**

```bash
docker compose build
```

- [ ] **Step 2: Start stack**

```bash
docker compose up -d
sleep 15
docker compose ps
```

Expected: all services show `healthy`.

- [ ] **Step 3: Check interface logs for ACP connection**

```bash
docker compose logs interface | tail -30
```

Expected: `[interface] started — agent: opencode acp`  
No `fatal` or `ECONNREFUSED` errors.

- [ ] **Step 4: Create a test message via PocketBase API**

```bash
# Get auth token
TOKEN=$(curl -s -X POST http://localhost:8090/api/collections/users/auth-with-password \
  -H 'Content-Type: application/json' \
  -d '{"identity":"your@email.com","password":"yourpassword"}' \
  | jq -r '.token')

# Create a chat
CHAT_ID=$(curl -s -X POST http://localhost:8090/api/collections/chats \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Test chat","user":"USER_ID_HERE"}' \
  | jq -r '.id')

# Send a user message
curl -s -X POST http://localhost:8090/api/collections/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"chat\":\"$CHAT_ID\",\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"Say hello in one word.\"}]}"
```

- [ ] **Step 5: Verify response appears**

```bash
sleep 10
curl -s "http://localhost:8090/api/collections/messages?filter=chat='$CHAT_ID'" \
  -H "Authorization: Bearer $TOKEN" | jq '.items[] | {role, acp_status}'
```

Expected: assistant message with `acp_status: "completed"` and `content` array containing text.

- [ ] **Step 6: Verify chat has acp_session_id**

```bash
curl -s "http://localhost:8090/api/collections/chats/$CHAT_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.acp_session_id'
```

Expected: non-null session ID string.

- [ ] **Step 7: Commit if all green**

```bash
git add .
git commit -m "chore: full ACP stack integration — opencode acp verified end-to-end"
```

---

## Out of Scope (Future Plans)

- **A2A bridge** (`services/a2a-bridge/`) — sub-agent escalation back to Poco. Separate plan.
- **Gemini CLI / Claude Code ACP containers** — additional harness configs. Separate plan once base is stable.
- **`harness_auth` OAuth flow** — Claude Code subscription login. Separate plan.
- **Flutter UI updates** — model picker showing harnesses + models, permission UI using new `acp_status` enum. Separate plan.
- **Seed data migration** — populating `harnesses`, `models`, `harness_models` with real data. Run manually post-deploy.
