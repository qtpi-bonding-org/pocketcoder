# PocketCoder Architecture (Updated)

## TL;DR - Current State

**What's Active:**
- ✅ **Plugin** (TypeScript) - Logs ALL permissions to `permissions` collection
- ✅ **PocketBase** - Auto-authorizes read/write, gates bash
- ✅ **Gateway** (Rust) - Ready for execution (dormant, waiting for shell wrapper)

**What's Dormant:**
- ⚠️ **Shell Wrapper** - Not routing to Gateway (commands execute in OpenCode container)

**Key Change:**
- Split `executions` table into `permissions` (Plugin) and `executions` (Gateway)
- No more duplicate records!

---

## System Overview

PocketCoder is a permission-gated AI coding assistant with three core components:

1. **OpenCode** (AI Reasoning Engine)
2. **PocketBase** (Authorization Authority + Data Store)
3. **Sandbox** (Isolated Execution Environment)

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  OpenCode Container (AI Reasoning)                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Plugin (TypeScript)                                  │  │
│  │  - Intercepts permission requests                     │  │
│  │  - Logs to permissions collection                     │  │
│  │  - Polls for authorization                            │  │
│  │  - Returns allow/deny                                 │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↓
                    POST /permissions
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  PocketBase Container (Authority + Storage)                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  PocketBase (Go)                                      │  │
│  │  - permissions collection (permission requests)       │  │
│  │  - executions collection (execution results)          │  │
│  │  - commands collection (command definitions)          │  │
│  │  - Auto-authorization hook (non-bash → authorized)    │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Gateway (Rust) :3001                                 │  │
│  │  - Receives bash commands (when shell wrapper active) │  │
│  │  - Executes in Sandbox via tmux                       │  │
│  │  - Logs results to executions collection              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↓
                    POST /exec (when active)
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  Sandbox Container (Isolated Execution)                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Tmux Session                                         │  │
│  │  - Persistent shell environment                       │  │
│  │  - Executes bash commands                             │  │
│  │  - Captures output and exit codes                     │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Permission Flow (Current: Plugin Active)

### Read/Write Permissions (Auto-Authorized)

```
AI: "Read file.ts"
    ↓
Plugin: Intercepts permission request
    ↓
Plugin: POST /permissions (permission: "read", status: "draft")
    ↓
PocketBase Hook: Auto-authorizes (status: "authorized")
    ↓
Plugin: Polls, sees "authorized"
    ↓
Plugin: Returns "allow" to OpenCode
    ↓
OpenCode: Executes read directly
```

### Bash Permissions (Gated)

```
AI: "Run ls -la"
    ↓
Plugin: Intercepts permission request
    ↓
Plugin: POST /permissions (permission: "bash", status: "draft")
    ↓
PocketBase Hook: Keeps as "draft" (requires approval)
    ↓
Plugin: Polls for authorization
    ↓
User: Authorizes via PocketBase UI (status: "authorized")
    ↓
Plugin: Sees "authorized"
    ↓
Plugin: Returns "allow" to OpenCode
    ↓
OpenCode: Executes bash directly (shell wrapper dormant)
```

---

## Database Schema

### `permissions` Collection (NEW)

**Purpose**: Track permission requests from Plugin

| Field | Type | Description |
|-------|------|-------------|
| `opencode_id` | text | Unique permission ID from OpenCode |
| `session_id` | text | Session identifier |
| `permission` | text | Type: bash, edit, read, external_directory |
| `patterns` | json | Array of file/path patterns |
| `metadata` | json | Additional context |
| `always` | json | Patterns for "always allow" |
| `message_id` | text | Tool message ID (optional) |
| `call_id` | text | Tool call ID (optional) |
| `status` | select | draft, authorized, denied |
| `source` | text | Always "opencode-plugin" |
| `message` | text | Human-readable description |

**Indexes**:
- Unique on `opencode_id`
- Index on `session_id`

### `executions` Collection (UPDATED)

**Purpose**: Track execution results from Gateway

| Field | Type | Description |
|-------|------|-------------|
| `permission` | relation | Links to permissions (optional) |
| `command` | relation | Links to commands table |
| `cwd` | text | Working directory |
| `status` | select | executing, completed, failed |
| `outputs` | json | stdout/stderr |
| `exit_code` | number | Process exit code |
| `source` | text | "gateway" or "opencode-plugin" |

**Deprecated fields** (kept for backward compatibility):
- `opencode_id`, `type`, `patterns`, `session_id`, `message_id`, `call_id`, `message`, `metadata`

### `commands` Collection

**Purpose**: Deduplicate command strings

| Field | Type | Description |
|-------|------|-------------|
| `hash` | text | SHA256 of command |
| `command` | text | The actual command string |

---

## Component Responsibilities

### Plugin (TypeScript)

**File**: `connector/pocketcoder-plugin.ts`

**Responsibilities**:
- Intercept ALL permission requests (read, write, bash, external_directory)
- Create permission records in PocketBase
- Poll for authorization
- Return allow/deny to OpenCode

**Does NOT**:
- Execute commands
- Make authorization decisions (PocketBase does this)

### PocketBase (Go)

**File**: `backend/main.go`

**Responsibilities**:
- Store permission requests and execution results
- Make authorization decisions via hooks
- Auto-authorize non-bash permissions
- Gate bash permissions (require manual approval)

**Authority Logic**:
```go
app.OnRecordCreate("permissions").Bind(&hook.Handler[*core.RecordEvent]{
    Func: func(e *core.RecordEvent) error {
        permission := e.Record.GetString("permission")
        if permission != "bash" {
            e.Record.Set("status", "authorized")  // Auto-allow
        } else {
            e.Record.Set("status", "draft")       // Gate
        }
        return e.Next()
    },
})
```

### Gateway (Rust)

**File**: `connector/src/main.rs`

**Responsibilities** (when active):
- Receive bash commands from shell wrapper
- Execute in isolated Sandbox via tmux
- Log execution results to PocketBase

**Does NOT**:
- Check permissions (trusts Plugin's authorization)
- Make authorization decisions

**Current State**: Dormant (shell wrapper not active)

### Sandbox (Tmux)

**Responsibilities**:
- Provide isolated execution environment
- Persist shell sessions
- Capture command output and exit codes

**Current State**: Running, ready for Gateway commands

---

## Future: Multi-Agent Orchestration

When Pallas (orchestrator AI) is built:

1. Pallas sends commands to Gateway
2. Gateway creates tmux windows for each agent
3. Multiple agents work in parallel
4. User can watch via `docker exec -it pocketcoder-sandbox tmux attach`

---

## Key Design Decisions

### 1. Separation of Concerns

- **Plugin** = Permission gatekeeper (what AI wants to do)
- **PocketBase** = Authorization authority (is it allowed?)
- **Gateway** = Execution engine (what actually ran)

### 2. No Duplicate Records

- Before: Both Plugin and Gateway created execution records
- After: Plugin creates permission, Gateway creates execution (linked via `permission` field)

### 3. Trust Model

- Plugin asks PocketBase for permission
- Gateway trusts that commands reaching it are authorized
- No redundant permission checks

### 4. Backward Compatibility

- Deprecated fields remain in `executions` for legacy support
- New code uses `permission` relation
- Future migration can clean up deprecated fields

---

## Testing

Run `./test_split.sh` to verify:
- ✅ permissions collection exists
- ✅ Auto-authorization works for non-bash
- ✅ Bash permissions stay as draft
- ✅ Plugin can create and poll permissions

---

## Next Steps

### Option 1: Keep Current (Plugin Only)
- Plugin gates all permissions
- OpenCode executes directly
- Good for: Single-agent, quick iteration

### Option 2: Activate Full Stack (Plugin + Gateway)
- Activate shell wrapper
- Route bash execution to Gateway
- Execute in isolated tmux
- Good for: Production, multi-agent, isolation

---

## Files

- `backend/pb_migrations/1700000003_permissions.go` - Permissions collection migration
- `connector/pocketcoder-plugin.ts` - Plugin (uses /permissions)
- `backend/main.go` - PocketBase (auto-authorization hook)
- `connector/src/main.rs` - Gateway (execution engine)
- `test_split.sh` - Test script
- `IMPLEMENTATION_PLAN.md` - Implementation guide
- `SPLIT_COMPLETE.md` - Completion summary
