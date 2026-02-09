# Permission vs Execution Split - Implementation Plan

## Overview

Split the `executions` table into two collections to eliminate duplicate records and clarify responsibilities:
- **`permissions`**: Plugin logs permission requests (what AI wants to do)
- **`executions`**: Gateway logs execution results (what actually ran)

## Schema Design (1:1 with OpenCode)

### `permissions` Collection

Maps exactly to OpenCode's `PermissionNext.Request` schema:

```typescript
// OpenCode Source: packages/opencode/src/permission/next.ts
export const Request = z.object({
  id: Identifier.schema("permission"),           // → opencode_id
  sessionID: Identifier.schema("session"),       // → session_id
  permission: z.string(),                        // → permission
  patterns: z.string().array(),                  // → patterns (JSON)
  metadata: z.record(z.string(), z.any()),       // → metadata (JSON)
  always: z.string().array(),                    // → always (JSON)
  tool: z.object({
    messageID: z.string(),                       // → message_id
    callID: z.string(),                          // → call_id
  }).optional(),
})
```

**PocketBase Schema:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `opencode_id` | text | yes | Unique permission ID (from OpenCode) |
| `session_id` | text | yes | Session identifier |
| `permission` | text | yes | Type: bash, edit, read, external_directory |
| `patterns` | json | no | Array of file/path patterns affected |
| `metadata` | json | no | Additional context from OpenCode |
| `always` | json | no | Patterns for "always allow" feature |
| `message_id` | text | no | Tool message ID (if from tool call) |
| `call_id` | text | no | Tool call ID (if from tool call) |
| `status` | select | yes | draft, authorized, denied |
| `source` | text | no | Always "opencode-plugin" |
| `message` | text | no | Human-readable description |

**Indexes:**
- Unique on `opencode_id`
- Index on `session_id`

### `executions` Collection (Updated)

**New Field:**
- `permission` (relation to permissions, optional)

**Existing Fields to Keep:**
- `command` (relation to commands)
- `cwd`, `status`, `outputs`, `exit_code`, `source`
- `created`, `updated`

**Deprecated Fields** (keep for backward compatibility):
- `opencode_id`, `type`, `patterns`, `session_id`, `message_id`, `call_id`, `message`, `metadata`

These will be removed in a future migration once all systems use the new flow.

## Updated Flow

### Before (Duplicate Records):
```
AI: "Run ls -la"
    ↓
Plugin: Creates execution #1 (type: bash) → Waits for auth
    ↓
User authorizes execution #1
    ↓
Gateway: Creates execution #2 (command: ls -la) → Waits for auth AGAIN ❌
    ↓
User has to authorize execution #2 (duplicate!)
```

### After (Clean Separation):
```
AI: "Run ls -la"
    ↓
Plugin: Creates permission #1 (permission: bash, patterns: []) → Waits for auth
    ↓
User authorizes permission #1
    ↓
Plugin: Returns "allow" to OpenCode
    ↓
Gateway: Creates execution #1 (permission: #1, command: ls -la)
Gateway: Executes immediately (trusts permission was authorized)
Gateway: Updates execution #1 with results
```

## Implementation Steps

### 1. Database Migration ✅

Created: `backend/pb_migrations/1700000003_permissions.go`

- Creates `permissions` collection with OpenCode-compatible schema
- Adds `permission` relation to `executions`
- Keeps deprecated fields for backward compatibility

### 2. Update Plugin (TypeScript)

**File:** `connector/pocketcoder-plugin.ts`

**Changes:**
```typescript
// OLD: POST to /executions
const intentRes = await fetch(`${POCKETBASE_URL}/api/collections/executions/records`, {
    body: JSON.stringify({
        opencode_id: info.id,
        type: info.permission || info.type,
        // ...
    })
});

// NEW: POST to /permissions
const intentRes = await fetch(`${POCKETBASE_URL}/api/collections/permissions/records`, {
    body: JSON.stringify({
        opencode_id: info.id,
        session_id: info.sessionID,
        permission: info.permission || info.type,
        patterns: info.patterns || [],
        metadata: info.metadata || {},
        always: info.always || [],
        message_id: info.tool?.messageID,
        call_id: info.tool?.callID,
        source: "opencode-plugin",
        status: "draft",
        message: info.message || "Requested via OpenCode"
    })
});
```

### 3. Update PocketBase Hooks (Go)

**File:** `backend/main.go`

**Changes:**
```go
// OLD: Auto-authorize on executions
app.OnRecordCreate("executions").Bind(&hook.Handler[*core.RecordEvent]{
    Func: func(e *core.RecordEvent) error {
        permType := e.Record.GetString("type")
        if permType != "bash" {
            e.Record.Set("status", "authorized")
        }
        return e.Next()
    },
})

// NEW: Auto-authorize on permissions
app.OnRecordCreate("permissions").Bind(&hook.Handler[*core.RecordEvent]{
    Func: func(e *core.RecordEvent) error {
        permission := e.Record.GetString("permission")
        if permission != "bash" {
            log.Printf("🛡️ Auto-authorizing: %s", permission)
            e.Record.Set("status", "authorized")
        } else {
            log.Printf("🛡️ Gating execution: %s", permission)
            e.Record.Set("status", "draft")
        }
        return e.Next()
    },
})
```

### 4. Update Proxy (Rust)

**File:** `proxy/src/main.rs`

**Changes:**
```rust
// REMOVE: Permission checking logic
// OLD:
let initial_status = if whitelisted { "authorized" } else { "draft" };
let exec_record = state.provider.create_execution(
    &cmd_record.id, cwd, initial_status, "proxy", metadata
).await?;

if initial_status == "draft" {
    // Poll for authorization...
}

// NEW: Trust that permission was already granted
let exec_record = state.provider.create_execution(
    &cmd_record.id, 
    cwd, 
    "executing",  // Start immediately
    "proxy", 
    metadata
).await?;

// Execute immediately (no permission check)
match state.driver.exec(&payload.cmd, Some(cwd)).await {
    Ok(res) => { /* update with results */ }
    Err(e) => { /* update with error */ }
}
```

**Optional:** Link execution to permission if metadata contains `permission_id`:
```rust
if let Some(permission_id) = payload.metadata.get("permission_id") {
    // Link execution to permission record
    body["permission"] = permission_id.clone();
}
```

## Benefits

✅ **No Duplicate Records**: Each bash command creates one permission + one execution
✅ **Clear Audit Trail**: Permission → Execution relationship
✅ **Separation of Concerns**: Plugin = authorization, Proxy = execution
✅ **OpenCode Compatible**: Schema matches OpenCode's internal structure
✅ **Backward Compatible**: Deprecated fields remain for legacy support

## Migration Path

1. Deploy migration (creates `permissions` table)
2. Update Plugin to use `/permissions` endpoint
3. Update PocketBase hooks to work on `permissions`
4. Update Proxy to remove permission logic
5. Test full flow
6. (Future) Remove deprecated fields from `executions`

## Testing Checklist

- [ ] Plugin creates permission record for read/write (auto-authorized)
- [ ] Plugin creates permission record for bash (draft)
- [ ] User can authorize bash permission via PocketBase UI
- [ ] Proxy creates execution record linked to permission
- [ ] Proxy executes without re-checking permission
- [ ] Execution record shows correct outputs and exit code
- [ ] No duplicate records in database
