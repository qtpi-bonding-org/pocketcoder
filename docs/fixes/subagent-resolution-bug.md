# Bug Fix: Subagent ChatID Resolution for OpenCode `task` Tool

## The Issue

When the `task` tool spawns a subagent, OpenCode sends a `session.created` SSE event containing the new subagent's `id` and its `parentID`. The relay currently has no handler for `session.created`, so this relationship is never recorded in the `subagents` table.

When the subagent subsequently requests a permission, the relay's `resolveChatID` function fails to link it to a chat. The permission is then saved with an empty `chat` relation, making it invisible in the Flux UI and effectively blocking Poco's progress.

## Root Cause

`services/pocketbase/pkg/relay/permissions.go`'s `listenForEvents` switch block lacks a `case "session.created":`.

Relevant log entry:
`⚠️ [Relay/SSE] Could not resolve Chat ID for session: ses_35c940a9bffeqNVxVebAE6nX9V` (Explore subagent)

## Proposed Fix

Add a handler for `session.created` in the relay that:
1. Extracts `id` (new session) and `parentID` (parent session).
2. Uses `resolveChatID(parentID)` to find the associated chat.
3. Immediately caches the `newID -> chatID` mapping in memory (to prevent a race with incoming permissions).
4. Persists the relationship using `registerSubagentInDB`.

### Implementation Detail (Draft)

```go
case "session.created":
    go r.handleSessionCreated(properties)

// ...

func (r *RelayService) handleSessionCreated(properties map[string]interface{}) {
    newSessionID, _ := properties["id"].(string)
    parentSessionID, _ := properties["parentID"].(string)

    if newSessionID == "" || parentSessionID == "" {
        return
    }

    chatID := r.resolveChatID(parentSessionID)
    if chatID == "" {
        r.app.Logger().Warn("⚠️ [Relay] session.created: parent resolution failed", "id", newSessionID)
        return
    }

    // Cache immediately to beat race conditions
    r.sessionChatCacheMu.Lock()
    r.sessionChatCache[newSessionID] = chatID
    r.sessionChatCacheMu.Unlock()

    r.registerSubagentInDB(chatID, newSessionID, "", 0, "")
}
```

## Current Workaround

The `task` tool has been disabled in `opencode.json` to prevent Poco from spawning subagents through this pathway until the relay is patched.




# How the Task Tool Works & Related SSE Events

## Overview

The Task Tool is OpenCode's mechanism for the primary AI agent to **spawn specialized sub-agents** to handle complex, multi-step work autonomously. It creates a new child session, runs a sub-agent inside it, and returns the result back to the parent agent.

---

## 1. Task Tool Definition

The tool is defined in `packages/opencode/src/tool/task.ts`. Its parameters are:

- `description` — a short 3–5 word description of the task
- `prompt` — the actual task instruction for the sub-agent
- `subagent_type` — which agent to invoke (e.g., `general`, `explore`)
- `task_id` *(optional)* — if provided, resumes an existing sub-agent session instead of creating a new one
- `command` *(optional)* — the slash command that triggered this task [1](#0-0) 

### What happens at initialization

When the tool is initialized (`TaskTool.define`), it filters the available agents to only those with mode !== `"primary"`, and further restricts them based on the calling agent's permissions. [2](#0-1) 

---

## 2. Task Tool Execution Flow

### Step 1: Permission Check

Unless the call was triggered explicitly by the user (e.g., via an `@agent` mention or a slash command), the tool asks for a permission grant before proceeding. [3](#0-2) 

### Step 2: Session Creation or Resumption

The tool either resumes an existing sub-session (if `task_id` is provided and found) or creates a **new child session** with a `parentID` pointing to the caller's session. The new session is created with restricted permissions — `todowrite`, `todoread`, and (unless the agent has the `task` permission) `task` are all denied, preventing sub-agents from spawning their own uncontrolled sub-tasks. [4](#0-3) 

### Step 3: Model Inheritance

The sub-agent uses the model configured in its agent definition, or falls back to the parent message's model. [5](#0-4) 

### Step 4: Prompt Execution

The tool calls `SessionPrompt.prompt(...)` on the child session, blocking until the sub-agent finishes. Abort propagation is handled: if the parent session is cancelled, the sub-agent session is also cancelled. [6](#0-5) 

### Step 5: Result Return

The result includes the final text from the sub-agent, wrapped with a `task_id` so the parent can resume the same sub-session later. [7](#0-6) 

---

## 3. Subtask Execution in the Session Loop

In `packages/opencode/src/session/prompt.ts`, the main session loop has special handling for **pending subtasks** that were queued as `SubtaskPart` on a user message. This is the path taken when a user explicitly invokes a task via `@agent` syntax. The loop picks up the task, creates an assistant message with a `ToolPart` of type `task`, runs `TaskTool`, and then marks it `completed` or `error`. [8](#0-7) 

---

## 4. SSE Events Related to the Task Tool

The server exposes a **Server-Sent Events (SSE)** endpoint at `GET /event`. When a client connects, it immediately receives a `server.connected` event, then subscribes to **all bus events** via `Bus.subscribeAll`, streaming each one as a JSON SSE frame. The stream stays alive with a heartbeat every 30 seconds and closes when the instance is disposed. [9](#0-8) 

### The Bus System

The `Bus` namespace is the internal pub/sub layer. Any code can `Bus.publish(EventDef, properties)` and all subscribers (including the SSE stream) receive it. [10](#0-9) 

### Events fired during task execution

When the task tool runs, the following bus events are emitted and streamed over SSE to any connected client:

| Event type | When fired |
|---|---|
| `session.created` | When the child session is first created |
| `session.updated` | When the session is touched/modified |
| `message.updated` | When the assistant message or user message is created/updated |
| `message.part.updated` | When a `ToolPart` changes state (`pending → running → completed/error`) |
| `message.part.delta` | Incremental text deltas during sub-agent streaming |
| `session.status` | When the sub-session becomes `busy` or `idle` |
| `session.idle` *(deprecated)* | When the sub-session finishes |

**Session events** are defined here: [11](#0-10) 

**Message/Part events** (the most granular — fired every time the `ToolPart` state changes for the task): [12](#0-11) 

**Session status events** (busy/idle transitions): [13](#0-12) 

### How a ToolPart tracks the task lifecycle

The `ToolPart` for a task call goes through these states, each triggering a `message.part.updated` SSE event:

1. `running` — task has started, includes the input and start time
2. `completed` — task finished, includes `output` (the `task_result` text), `title`, `metadata` (with `sessionId` and `model`), and `time.end`
3. `error` — task failed, includes error message and timing [14](#0-13) 

---

## Data Flow Diagram

```mermaid
sequenceDiagram
    participant Client as "Client (UI)"
    participant SSE as "GET /event (SSE)"
    participant Bus as "Bus (pub/sub)"
    participant Loop as "Session Prompt Loop"
    participant TaskTool as "TaskTool.execute()"
    participant ChildSession as "Child Session"

    Client->>SSE: Connect
    SSE-->>Client: server.connected

    Loop->>TaskTool: execute(params, ctx)
    TaskTool->>ChildSession: Session.create({ parentID })
    ChildSession->>Bus: publish session.created
    Bus->>SSE: event
    SSE-->>Client: session.created

    TaskTool->>Loop: updatePart (status: running)
    Loop->>Bus: publish message.part.updated
    Bus->>SSE: event
    SSE-->>Client: message.part.updated (running)

    TaskTool->>ChildSession: SessionPrompt.prompt(...)
    ChildSession->>Bus: publish session.status (busy)
    Bus->>SSE: event
    SSE-->>Client: session.status (busy)

    ChildSession->>Bus: publish message.part.delta (streaming)
    Bus->>SSE: event
    SSE-->>Client: message.part.delta

    ChildSession->>Bus: publish session.status (idle)
    Bus->>SSE: event
    SSE-->>Client: session.status (idle)

    TaskTool->>Loop: updatePart (status: completed)
    Loop->>Bus: publish message.part.updated
    Bus->>SSE: event
    SSE-->>Client: message.part.updated (completed)
```

---

## Notes

- The SSE endpoint at `/event` is a **global stream** — it delivers events from **all sessions**, including child sessions spawned by the Task Tool. Clients need to filter by `sessionID` in the event `properties` to distinguish parent vs. child activity.
- The `task_id` returned in the tool output (which is the child session ID) can be passed back as `task_id` in a future Task Tool call to **resume** the same sub-agent conversation instead of starting fresh.
- Sub-agents spawned by the Task Tool **cannot** themselves use `todowrite` or `todoread` by default, and cannot spawn further sub-agents unless their agent definition explicitly has the `task` permission. [15](#0-14)

### Citations

**File:** packages/opencode/src/tool/task.ts (L14-25)
```typescript
const parameters = z.object({
  description: z.string().describe("A short (3-5 words) description of the task"),
  prompt: z.string().describe("The task for the agent to perform"),
  subagent_type: z.string().describe("The type of specialized agent to use for this task"),
  task_id: z
    .string()
    .describe(
      "This should only be set if you mean to resume a previous task (you can pass a prior task_id and the task will continue the same subagent session as before instead of creating a fresh one)",
    )
    .optional(),
  command: z.string().describe("The command that triggered this task").optional(),
})
```

**File:** packages/opencode/src/tool/task.ts (L27-41)
```typescript
export const TaskTool = Tool.define("task", async (ctx) => {
  const agents = await Agent.list().then((x) => x.filter((a) => a.mode !== "primary"))

  // Filter agents by permissions if agent provided
  const caller = ctx?.agent
  const accessibleAgents = caller
    ? agents.filter((a) => PermissionNext.evaluate("task", a.name, caller.permission).action !== "deny")
    : agents

  const description = DESCRIPTION.replace(
    "{agents}",
    accessibleAgents
      .map((a) => `- ${a.name}: ${a.description ?? "This subagent should only be called manually by the user."}`)
      .join("\n"),
  )
```

**File:** packages/opencode/src/tool/task.ts (L49-59)
```typescript
      if (!ctx.extra?.bypassAgentCheck) {
        await ctx.ask({
          permission: "task",
          patterns: [params.subagent_type],
          always: ["*"],
          metadata: {
            description: params.description,
            subagent_type: params.subagent_type,
          },
        })
      }
```

**File:** packages/opencode/src/tool/task.ts (L66-102)
```typescript
      const session = await iife(async () => {
        if (params.task_id) {
          const found = await Session.get(params.task_id).catch(() => {})
          if (found) return found
        }

        return await Session.create({
          parentID: ctx.sessionID,
          title: params.description + ` (@${agent.name} subagent)`,
          permission: [
            {
              permission: "todowrite",
              pattern: "*",
              action: "deny",
            },
            {
              permission: "todoread",
              pattern: "*",
              action: "deny",
            },
            ...(hasTaskPermission
              ? []
              : [
                  {
                    permission: "task" as const,
                    pattern: "*" as const,
                    action: "deny" as const,
                  },
                ]),
            ...(config.experimental?.primary_tools?.map((t) => ({
              pattern: "*",
              action: "allow" as const,
              permission: t,
            })) ?? []),
          ],
        })
      })
```

**File:** packages/opencode/src/tool/task.ts (L106-117)
```typescript
      const model = agent.model ?? {
        modelID: msg.info.modelID,
        providerID: msg.info.providerID,
      }

      ctx.metadata({
        title: params.description,
        metadata: {
          sessionId: session.id,
          model,
        },
      })
```

**File:** packages/opencode/src/tool/task.ts (L119-143)
```typescript
      const messageID = Identifier.ascending("message")

      function cancel() {
        SessionPrompt.cancel(session.id)
      }
      ctx.abort.addEventListener("abort", cancel)
      using _ = defer(() => ctx.abort.removeEventListener("abort", cancel))
      const promptParts = await SessionPrompt.resolvePromptParts(params.prompt)

      const result = await SessionPrompt.prompt({
        messageID,
        sessionID: session.id,
        model: {
          modelID: model.modelID,
          providerID: model.providerID,
        },
        agent: agent.name,
        tools: {
          todowrite: false,
          todoread: false,
          ...(hasTaskPermission ? {} : { task: false }),
          ...Object.fromEntries((config.experimental?.primary_tools ?? []).map((t) => [t, false])),
        },
        parts: promptParts,
      })
```

**File:** packages/opencode/src/tool/task.ts (L145-162)
```typescript
      const text = result.parts.findLast((x) => x.type === "text")?.text ?? ""

      const output = [
        `task_id: ${session.id} (for resuming to continue this task if needed)`,
        "",
        "<task_result>",
        text,
        "</task_result>",
      ].join("\n")

      return {
        title: params.description,
        metadata: {
          sessionId: session.id,
          model,
        },
        output,
      }
```

**File:** packages/opencode/src/session/prompt.ts (L350-526)
```typescript
      // pending subtask
      // TODO: centralize "invoke tool" logic
      if (task?.type === "subtask") {
        const taskTool = await TaskTool.init()
        const taskModel = task.model ? await Provider.getModel(task.model.providerID, task.model.modelID) : model
        const assistantMessage = (await Session.updateMessage({
          id: Identifier.ascending("message"),
          role: "assistant",
          parentID: lastUser.id,
          sessionID,
          mode: task.agent,
          agent: task.agent,
          variant: lastUser.variant,
          path: {
            cwd: Instance.directory,
            root: Instance.worktree,
          },
          cost: 0,
          tokens: {
            input: 0,
            output: 0,
            reasoning: 0,
            cache: { read: 0, write: 0 },
          },
          modelID: taskModel.id,
          providerID: taskModel.providerID,
          time: {
            created: Date.now(),
          },
        })) as MessageV2.Assistant
        let part = (await Session.updatePart({
          id: Identifier.ascending("part"),
          messageID: assistantMessage.id,
          sessionID: assistantMessage.sessionID,
          type: "tool",
          callID: ulid(),
          tool: TaskTool.id,
          state: {
            status: "running",
            input: {
              prompt: task.prompt,
              description: task.description,
              subagent_type: task.agent,
              command: task.command,
            },
            time: {
              start: Date.now(),
            },
          },
        })) as MessageV2.ToolPart
        const taskArgs = {
          prompt: task.prompt,
          description: task.description,
          subagent_type: task.agent,
          command: task.command,
        }
        await Plugin.trigger(
          "tool.execute.before",
          {
            tool: "task",
            sessionID,
            callID: part.id,
          },
          { args: taskArgs },
        )
        let executionError: Error | undefined
        const taskAgent = await Agent.get(task.agent)
        const taskCtx: Tool.Context = {
          agent: task.agent,
          messageID: assistantMessage.id,
          sessionID: sessionID,
          abort,
          callID: part.callID,
          extra: { bypassAgentCheck: true },
          messages: msgs,
          async metadata(input) {
            await Session.updatePart({
              ...part,
              type: "tool",
              state: {
                ...part.state,
                ...input,
              },
            } satisfies MessageV2.ToolPart)
          },
          async ask(req) {
            await PermissionNext.ask({
              ...req,
              sessionID: sessionID,
              ruleset: PermissionNext.merge(taskAgent.permission, session.permission ?? []),
            })
          },
        }
        const result = await taskTool.execute(taskArgs, taskCtx).catch((error) => {
          executionError = error
          log.error("subtask execution failed", { error, agent: task.agent, description: task.description })
          return undefined
        })
        const attachments = result?.attachments?.map((attachment) => ({
          ...attachment,
          id: Identifier.ascending("part"),
          sessionID,
          messageID: assistantMessage.id,
        }))
        await Plugin.trigger(
          "tool.execute.after",
          {
            tool: "task",
            sessionID,
            callID: part.id,
            args: taskArgs,
          },
          result,
        )
        assistantMessage.finish = "tool-calls"
        assistantMessage.time.completed = Date.now()
        await Session.updateMessage(assistantMessage)
        if (result && part.state.status === "running") {
          await Session.updatePart({
            ...part,
            state: {
              status: "completed",
              input: part.state.input,
              title: result.title,
              metadata: result.metadata,
              output: result.output,
              attachments,
              time: {
                ...part.state.time,
                end: Date.now(),
              },
            },
          } satisfies MessageV2.ToolPart)
        }
        if (!result) {
          await Session.updatePart({
            ...part,
            state: {
              status: "error",
              error: executionError ? `Tool execution failed: ${executionError.message}` : "Tool execution failed",
              time: {
                start: part.state.status === "running" ? part.state.time.start : Date.now(),
                end: Date.now(),
              },
              metadata: part.metadata,
              input: part.state.input,
            },
          } satisfies MessageV2.ToolPart)
        }

        if (task.command) {
          // Add synthetic user message to prevent certain reasoning models from erroring
          // If we create assistant messages w/ out user ones following mid loop thinking signatures
          // will be missing and it can cause errors for models like gemini for example
          const summaryUserMsg: MessageV2.User = {
            id: Identifier.ascending("message"),
            sessionID,
            role: "user",
            time: {
              created: Date.now(),
            },
            agent: lastUser.agent,
            model: lastUser.model,
          }
          await Session.updateMessage(summaryUserMsg)
          await Session.updatePart({
            id: Identifier.ascending("part"),
            messageID: summaryUserMsg.id,
            sessionID,
            type: "text",
            text: "Summarize the task tool output above and continue with your task.",
            synthetic: true,
          } satisfies MessageV2.TextPart)
        }

        continue
      }
```

**File:** packages/opencode/src/server/server.ts (L486-539)
```typescript
          "/event",
          describeRoute({
            summary: "Subscribe to events",
            description: "Get events",
            operationId: "event.subscribe",
            responses: {
              200: {
                description: "Event stream",
                content: {
                  "text/event-stream": {
                    schema: resolver(BusEvent.payloads()),
                  },
                },
              },
            },
          }),
          async (c) => {
            log.info("event connected")
            return streamSSE(c, async (stream) => {
              stream.writeSSE({
                data: JSON.stringify({
                  type: "server.connected",
                  properties: {},
                }),
              })
              const unsub = Bus.subscribeAll(async (event) => {
                await stream.writeSSE({
                  data: JSON.stringify(event),
                })
                if (event.type === Bus.InstanceDisposed.type) {
                  stream.close()
                }
              })

              // Send heartbeat every 30s to prevent WKWebView timeout (60s default)
              const heartbeat = setInterval(() => {
                stream.writeSSE({
                  data: JSON.stringify({
                    type: "server.heartbeat",
                    properties: {},
                  }),
                })
              }, 30000)

              await new Promise<void>((resolve) => {
                stream.onAbort(() => {
                  clearInterval(heartbeat)
                  unsub()
                  resolve()
                  log.info("event disconnected")
                })
              })
            })
          },
```

**File:** packages/opencode/src/bus/index.ts (L41-64)
```typescript
  export async function publish<Definition extends BusEvent.Definition>(
    def: Definition,
    properties: z.output<Definition["properties"]>,
  ) {
    const payload = {
      type: def.type,
      properties,
    }
    log.info("publishing", {
      type: def.type,
    })
    const pending = []
    for (const key of [def.type, "*"]) {
      const match = state().subscriptions.get(key)
      for (const sub of match ?? []) {
        pending.push(sub(payload))
      }
    }
    GlobalBus.emit("event", {
      directory: Instance.directory,
      payload,
    })
    return Promise.all(pending)
  }
```

**File:** packages/opencode/src/session/index.ts (L157-190)
```typescript
  export const Event = {
    Created: BusEvent.define(
      "session.created",
      z.object({
        info: Info,
      }),
    ),
    Updated: BusEvent.define(
      "session.updated",
      z.object({
        info: Info,
      }),
    ),
    Deleted: BusEvent.define(
      "session.deleted",
      z.object({
        info: Info,
      }),
    ),
    Diff: BusEvent.define(
      "session.diff",
      z.object({
        sessionID: z.string(),
        diff: Snapshot.FileDiff.array(),
      }),
    ),
    Error: BusEvent.define(
      "session.error",
      z.object({
        sessionID: z.string().optional(),
        error: MessageV2.Assistant.shape.error,
      }),
    ),
  }
```

**File:** packages/opencode/src/session/message-v2.ts (L261-338)
```typescript
  export const ToolStatePending = z
    .object({
      status: z.literal("pending"),
      input: z.record(z.string(), z.any()),
      raw: z.string(),
    })
    .meta({
      ref: "ToolStatePending",
    })

  export type ToolStatePending = z.infer<typeof ToolStatePending>

  export const ToolStateRunning = z
    .object({
      status: z.literal("running"),
      input: z.record(z.string(), z.any()),
      title: z.string().optional(),
      metadata: z.record(z.string(), z.any()).optional(),
      time: z.object({
        start: z.number(),
      }),
    })
    .meta({
      ref: "ToolStateRunning",
    })
  export type ToolStateRunning = z.infer<typeof ToolStateRunning>

  export const ToolStateCompleted = z
    .object({
      status: z.literal("completed"),
      input: z.record(z.string(), z.any()),
      output: z.string(),
      title: z.string(),
      metadata: z.record(z.string(), z.any()),
      time: z.object({
        start: z.number(),
        end: z.number(),
        compacted: z.number().optional(),
      }),
      attachments: FilePart.array().optional(),
    })
    .meta({
      ref: "ToolStateCompleted",
    })
  export type ToolStateCompleted = z.infer<typeof ToolStateCompleted>

  export const ToolStateError = z
    .object({
      status: z.literal("error"),
      input: z.record(z.string(), z.any()),
      error: z.string(),
      metadata: z.record(z.string(), z.any()).optional(),
      time: z.object({
        start: z.number(),
        end: z.number(),
      }),
    })
    .meta({
      ref: "ToolStateError",
    })
  export type ToolStateError = z.infer<typeof ToolStateError>

  export const ToolState = z
    .discriminatedUnion("status", [ToolStatePending, ToolStateRunning, ToolStateCompleted, ToolStateError])
    .meta({
      ref: "ToolState",
    })

  export const ToolPart = PartBase.extend({
    type: z.literal("tool"),
    callID: z.string(),
    tool: z.string(),
    state: ToolState,
    metadata: z.record(z.string(), z.any()).optional(),
  }).meta({
    ref: "ToolPart",
  })
  export type ToolPart = z.infer<typeof ToolPart>
```

**File:** packages/opencode/src/session/message-v2.ts (L445-483)
```typescript
  export const Event = {
    Updated: BusEvent.define(
      "message.updated",
      z.object({
        info: Info,
      }),
    ),
    Removed: BusEvent.define(
      "message.removed",
      z.object({
        sessionID: z.string(),
        messageID: z.string(),
      }),
    ),
    PartUpdated: BusEvent.define(
      "message.part.updated",
      z.object({
        part: Part,
      }),
    ),
    PartDelta: BusEvent.define(
      "message.part.delta",
      z.object({
        sessionID: z.string(),
        messageID: z.string(),
        partID: z.string(),
        field: z.string(),
        delta: z.string(),
      }),
    ),
    PartRemoved: BusEvent.define(
      "message.part.removed",
      z.object({
        sessionID: z.string(),
        messageID: z.string(),
        partID: z.string(),
      }),
    ),
  }
```

**File:** packages/opencode/src/session/status.ts (L27-42)
```typescript
  export const Event = {
    Status: BusEvent.define(
      "session.status",
      z.object({
        sessionID: z.string(),
        status: Info,
      }),
    ),
    // deprecated
    Idle: BusEvent.define(
      "session.idle",
      z.object({
        sessionID: z.string(),
      }),
    ),
  }
```
