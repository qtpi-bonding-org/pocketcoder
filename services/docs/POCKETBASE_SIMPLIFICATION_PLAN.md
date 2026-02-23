# PocketBase Simplification Plan

## Philosophy

**PocketBase = Control Plane for OpenCode**

PocketBase handles:
- User configuration (agents, prompts, models, MCP servers)
- Human-in-the-loop (permissions, approvals)
- Operational state (message delivery, chat turns, health)
- Multi-user/multi-tenant concerns

**OpenCode = Analytics & Execution Engine**

OpenCode handles:
- Full conversation history
- Token usage & cost tracking
- Performance metrics
- Session management

## Separation of Concerns

```
┌─────────────────────────────────────────────────────────────┐
│ PocketBase (Control Plane)                                  │
│ - What users configure                                       │
│ - What needs approval                                        │
│ - What needs access control                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ OpenCode (Execution & Analytics)                            │
│ - What happened (full history)                              │
│ - How much it cost                                           │
│ - How long it took                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Collections to Keep

### Core Platform (Authentication & Multi-tenancy)

✅ **users**
- Purpose: Authentication, authorization, role-based access
- Why: Multi-user platform foundation

✅ **chats**
- Purpose: User → OpenCode session mapping, turn management, chat list
- Why: Operational state for UI (whose turn, last active, preview)
- Fields: `title`, `ai_engine_session_id`, `engine_type`, `user`, `agent`, `last_active`, `preview`, `turn`, `description`, `archived`, `tags`, `created`, `updated`

✅ **messages** (SIMPLIFIED - see below)
- Purpose: Message delivery tracking, UI state, content display
- Why: Operational state (is message sending? did it fail?)

### Configuration (User-Editable Settings)

✅ **ai_agents**
- Purpose: Agent configuration (temperature, tools, permissions)
- Why: Users configure agents via UI (like VS Code settings)

✅ **ai_prompts**
- Purpose: System prompts library
- Why: Users can customize/create prompts

✅ **ai_models**
- Purpose: Available models registry
- Why: Users select which models to use

### Human-in-the-Loop (Security & Governance)

✅ **permissions**
- Purpose: Permission requests & approval workflow
- Why: Core security feature - HITL approval system

✅ **mcp_servers**
- Purpose: MCP server approval workflow
- Why: Security gate for installing MCP servers

### Infrastructure & Monitoring

✅ **healthchecks**
- Purpose: System health monitoring
- Why: Relay watchdog, status dashboard

✅ **ssh_keys**
- Purpose: User SSH key management
- Why: Users upload keys via UI for remote access

✅ **whitelist_targets** & **whitelist_actions**
- Purpose: Pre-approved patterns (auto-approve rules)
- Why: Reduces HITL friction for trusted operations

✅ **subagents**
- Purpose: Subagent lineage tracking
- Why: Shows delegation hierarchy in UI

✅ **proposals** & **sops**
- Purpose: Governance workflow (proposal → approval → SOP)
- Why: System evolution with human oversight

---

## Messages Table Simplification

### Current State (Duplicated Data)

```go
messages {
  // Linkage
  chat                    ✅ KEEP
  role                    ✅ KEEP
  ai_engine_message_id    ✅ KEEP
  parent_id               ✅ KEEP
  
  // Operational State
  user_message_status     ✅ KEEP (pending/sending/delivered/failed)
  engine_message_status   ✅ KEEP (processing/completed/failed/aborted)
  
  // Content
  parts                   ✅ KEEP (for display)
  
  // Timestamps
  created                 ✅ KEEP
  updated                 ✅ KEEP
  
  // DUPLICATED FROM OPENCODE (Remove)
  cost                    ❌ REMOVE (query OpenCode)
  tokens                  ❌ REMOVE (query OpenCode)
  agent_name              ❌ REMOVE (query OpenCode)
  provider_name           ❌ REMOVE (query OpenCode)
  model_name              ❌ REMOVE (query OpenCode)
  finish_reason           ❌ REMOVE (query OpenCode)
  error                   ❌ REMOVE (query OpenCode)
  metadata                ❌ REMOVE (not used)
}
```

### Simplified Schema

```go
messages {
  // Linkage (maps to OpenCode)
  chat                    string   (relation to chats)
  role                    enum     (user/assistant/system)
  ai_engine_message_id    string   (OpenCode message ID)
  parent_id               string   (thread structure)
  
  // Operational State (PocketBase-specific)
  user_message_status     enum     (pending/sending/delivered/failed)
  engine_message_status   enum     (processing/completed/failed/aborted)
  
  // Content (for display)
  parts                   json     (message content)
  
  // Timestamps
  created                 datetime
  updated                 datetime
}
```

### Why This Works

**For UI Display:**
- Show message content: `parts` field
- Show delivery status: `user_message_status`
- Show processing status: `engine_message_status`

**For Analytics (query OpenCode):**
- Token usage: `SELECT tokens FROM opencode.db WHERE id = ai_engine_message_id`
- Cost: `SELECT cost FROM opencode.db WHERE id = ai_engine_message_id`
- Model info: `SELECT provider, model FROM opencode.db WHERE id = ai_engine_message_id`

**For SQLPage Dashboards:**
```sql
-- PocketBase: Operational metrics
SELECT 
  COUNT(*) as total_messages,
  SUM(CASE WHEN user_message_status = 'failed' THEN 1 ELSE 0 END) as failed_deliveries
FROM messages;

-- OpenCode: Analytics
SELECT 
  SUM(cost) as total_cost,
  SUM(tokens_total) as total_tokens,
  provider,
  model
FROM opencode.db.messages
GROUP BY provider, model;
```

---

## Implementation Steps

### Phase 1: Schema Migration (Backend)

1. **Create new migration** (`backend/pb_migrations/YYYYMMDD_simplify_messages.go`)
   - Remove fields: `cost`, `tokens`, `agent_name`, `provider_name`, `model_name`, `finish_reason`, `error`, `metadata`
   - Keep fields: `chat`, `role`, `ai_engine_message_id`, `parent_id`, `user_message_status`, `engine_message_status`, `parts`, `created`, `updated`

2. **Update relay sync logic** (`backend/pkg/relay/messages.go`)
   - Remove code that syncs `cost`, `tokens`, `agent_name`, etc.
   - Keep code that syncs `parts`, `status`, `delivery`

3. **Update recovery pump** (no changes needed - only uses delivery status)

### Phase 2: Client Updates (Flutter)
0. run scripts/export_schema.sh

1. **Update models** (`client/lib/domain/chat/chat_message.dart`)
   - Remove fields: `cost`, `tokens`, `agentName`, `providerName`, `modelName`, `finishReason`, `error`, `metadata`
   - Keep fields: `chat`, `role`, `aiEngineMessageId`, `parentId`, `userMessageStatus`, `engineMessageStatus`, `parts`, `created`, `updated`

2. **Update UI** (if displaying cost/tokens)
   - Add OpenCode query for analytics
   - Or remove analytics from message view (show in separate stats page)

### Phase 3: SQLPage Dashboards

SQLPage will have read-only access to three SQLite databases:

1. **PocketBase DB** (`pb_data/data.db`)
   - Operational metrics: delivery status, health checks, active chats
   - User management: users, permissions, approvals
   - Configuration: agents, prompts, models, MCP servers

2. **OpenCode DB** (`~/.local/share/opencode/opencode.db`)
   - Analytics: token usage, costs, performance
   - Full conversation history
   - Session management

3. **CAO MCP DB** (`/root/.aws/cli-agent-orchestrator/db/cli-agent-orchestrator.db`)
   - Subagent task dashboard
   - Task status, progress, results
   - Subagent execution history
   - Terminal/tmux session tracking

**Docker Volume Mounts:**
```yaml
sqlpage:
  volumes:
    - pb_data:/database/pocketbase:ro           # PocketBase
    - opencode_data:/database/opencode:ro       # OpenCode
    - cao_db:/database/cao:ro                   # CAO
```

**Database Paths in SQLPage:**
- PocketBase: `/database/pocketbase/data.db`
- OpenCode: `/database/opencode/opencode.db`
- CAO: `/database/cao/cli-agent-orchestrator.db`

**Dashboard Examples:**

1. **Operational Dashboard** (`sqlpage/operational.sql`)
   ```sql
   -- Query PocketBase for delivery metrics
   SELECT 
     COUNT(*) as total_messages,
     SUM(CASE WHEN user_message_status = 'failed' THEN 1 ELSE 0 END) as failed
   FROM messages;
   ```

2. **Analytics Dashboard** (`sqlpage/analytics.sql`)
   ```sql
   -- Query OpenCode for token usage
   SELECT 
     SUM(cost) as total_cost,
     SUM(tokens_total) as total_tokens,
     provider, model
   FROM opencode_messages
   GROUP BY provider, model;
   ```

3. **Subagent Dashboard** (`sqlpage/subagents.sql`)
   ```sql
   -- Query CAO MCP for task status
   SELECT 
     task_id,
     status,
     progress,
     agent_profile
   FROM cao_tasks
   WHERE status IN ('running', 'pending');
   ```

4. **Combined Overview** (`sqlpage/overview.sql`)
   - Join all three databases for comprehensive system view

---

## Benefits

### 1. Clear Separation of Concerns
- PocketBase: "What users control"
- OpenCode: "What happened"

### 2. Reduced Duplication
- Single source of truth for analytics (OpenCode)
- No sync drift between PocketBase and OpenCode

### 3. Simpler Sync Logic
- Relay only syncs operational state
- No need to keep cost/tokens in sync

### 4. Better Performance
- Smaller messages table (~40% reduction)
- Faster queries for chat UI

### 5. Clearer Data Model
- PocketBase schema reflects its purpose (control plane)
- OpenCode schema reflects its purpose (execution history)

---

## Migration Strategy

### No Backward Compatibility Needed

This is a breaking change - we'll do a clean migration:

1. **Create new migration** that drops unused fields
2. **Update all code** in same release
3. **No gradual rollout** - clean break

### Why This Works

- Early stage product (no production users yet)
- All clients under our control
- Simpler than maintaining compatibility layer
- Faster to implement

### Migration Steps

1. Create migration to drop fields
2. Update backend relay code
3. Update Flutter client models
4. Deploy everything together
5. Test end-to-end

---

## Success Metrics

After simplification:

✅ Messages table size reduced by ~40%
✅ Relay sync logic simplified (fewer fields to sync)
✅ Clear documentation of PocketBase vs OpenCode roles
✅ SQLPage dashboards query three databases:
   - PocketBase (operational)
   - OpenCode (analytics)
   - CAO MCP (subagent tasks)
✅ No loss of functionality (analytics still available via OpenCode)

---

## Conclusion

This simplification maintains all functionality while establishing clear boundaries:

- **PocketBase** = Control plane (config, HITL, operational state)
- **OpenCode** = Execution engine (history, analytics, metrics)

The result is a cleaner architecture that's easier to understand, maintain, and scale.
